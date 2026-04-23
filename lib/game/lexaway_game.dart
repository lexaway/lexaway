import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';

import '../data/world_state_repository.dart';
import 'audio_manager.dart';
import 'components/biome_parallax.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'components/wind_lines.dart';
import 'events.dart';
import 'movement_controller.dart';
import 'systems/animation_controller.dart';
import 'systems/audio_cue_controller.dart';
import 'systems/dialogue_controller.dart';
import 'systems/scroll_controller.dart';
import 'systems/wind_controller.dart';
import 'systems/world_state_persister.dart';
import 'systems/world_streamer.dart';
import 'world/creature_layer.dart';
import 'world/entity_footprints.dart';
import 'world/world_generator.dart';
import 'world/world_map.dart';
import 'world/world_renderer.dart';

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  /// Tiles of ground covered by a single (non-streak) correct answer.
  /// These timings feed the session-length labels on daily-goal tiles —
  /// if you tweak them, re-check `dailyGoalPresets` in
  /// `lib/providers/daily_goal.dart`.
  static const int tilesPerCorrectAnswer = 4;
  static const double walkSpeed = 80;
  static const double walkTarget = tilesPerCorrectAnswer * 16 * pixelScale;
  static const double cloudDrift = 1.5;

  final WorldStateRepository worldStateRepository;
  final String characterPath;
  String _fontFamily;
  String _locale;

  /// The currently-rendered font family for in-game text. Updating this
  /// forwards the change to [speechBubble] so a Settings change is picked up
  /// while the game is running. If [onLoad] hasn't completed yet, the new
  /// value is stored and picked up when [speechBubble] is constructed there.
  String get fontFamily => _fontFamily;
  set fontFamily(String value) {
    if (value == _fontFamily) return;
    _fontFamily = value;
    if (isLoaded) speechBubble.fontFamily = value;
  }

  LexawayGame({
    required this.worldStateRepository,
    String locale = 'en',
    required this.characterPath,
    required String fontFamily,
  })  : _locale = locale,
        _fontFamily = fontFamily;

  String get locale => _locale;
  set locale(String value) {
    if (value == _locale) return;
    _locale = value;
    SpeechMessages.load(value);
  }

  /// Typed event bus for sibling systems. Constructed eagerly so any
  /// component can subscribe inside its own `onLoad` without boot-order
  /// surprises.
  final GameEvents events = GameEvents();

  late WorldMap worldMap;
  late WorldRenderer worldRenderer;
  late CreatureLayer creatureLayer;
  late Player player;
  late Ground ground;
  late BiomeParallax biomeParallax;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;
  late WindLines windLines;
  late MovementController movementController;
  late WorldStreamer worldStreamer;
  late WorldStatePersister worldStatePersister;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final saved = worldStateRepository.load();
    final seed = saved?.seed ?? Random().nextInt(1 << 32);

    final entityFootprints = await loadEntityFootprints();
    worldMap = WorldGenerator(entityFootprints: entityFootprints)
        .generate(seed);
    // Replay previously-persisted extensions at their original seeds so
    // worldMap.segments matches the saved scroll offset before any
    // components that read the map come online. [WorldStreamer.extend]
    // is a no-op on the event bus while unmounted, so replay doesn't
    // spuriously dirty the persister.
    worldStreamer = WorldStreamer(
      worldMap: worldMap,
      entityFootprints: entityFootprints,
    );
    for (var i = 0; i < (saved?.extensions ?? 0); i++) {
      worldStreamer.extend();
    }

    worldStatePersister = WorldStatePersister(
      repository: worldStateRepository,
      initialCollectedCoins: saved?.collectedCoins ?? const [],
    );

    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    biomeParallax = BiomeParallax(
      initialScrollOffset: saved?.scrollOffset ?? 0,
    )..size = Vector2(size.x, parallaxHeight);
    await add(biomeParallax);

    ground = Ground(worldMap: worldMap)..priority = 1;
    if (saved != null) {
      ground.scrollOffset = saved.scrollOffset;
    }
    add(ground);

    worldRenderer = WorldRenderer(worldMap)..priority = 1;
    add(worldRenderer);

    creatureLayer = CreatureLayer(worldMap)..priority = 1;
    add(creatureLayer);

    // CoinManager shares the collectedCoins Set with the persister so its
    // spawn loop can dedup against saved pickups; the persister owns the
    // mutation lifecycle via its CoinCollected subscription.
    coinManager = CoinManager(
      worldMap: worldMap,
      collectedCoins: worldStatePersister.collectedCoins,
    )..priority = 1;
    add(coinManager);

    player = Player(spritePath: characterPath)..priority = 2;
    await add(player);
    player.play(DinoAnim.scan);

    windLines = WindLines()..priority = 2;
    add(windLines);

    speechBubble = SpeechBubble(follow: player, fontFamily: _fontFamily)
      ..priority = 3;
    add(speechBubble);

    movementController = MovementController();
    add(movementController);

    add(AudioCueController());
    add(ScrollController());
    add(WindController());
    add(AnimationController());
    add(DialogueController());
    add(worldStreamer);
    // Persister is added AFTER coinManager so its CoinCollected handler
    // runs second. CoinManager's handler reads the still-alive Coin's
    // sprite state to spawn the fly effect; the persister then mutates
    // collectedCoins. Reordering would still work today (sync emit, both
    // handlers run before the next frame), but the trajectory would be
    // first-frame race-prone — keep them in this order.
    add(worldStatePersister);

    events.on<WorldExtended>().listen((_) => _loadNewBiomes());

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);

    // Persist the seed on first run. The persister isn't mounted yet so
    // its per-frame dirty drain hasn't started — flush() writes directly.
    if (saved == null) worldStatePersister.flush();
  }

  void _loadNewBiomes() {
    for (final seg in worldMap.segments) {
      ground.ensureBiomeLoaded(seg.biome);
      worldRenderer.ensureBiomeLoaded(seg.biome);
      creatureLayer.ensureBiomeLoaded(seg.biome);
      biomeParallax.ensureBiomeLoaded(seg.biome);
    }
  }

  void correctAnswer({required int streak, required String answer}) {
    movementController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    movementController.wrongAnswer();
  }

  /// Toggle debug mode: dino walks continuously without answering.
  void toggleDebugWalk() => movementController.toggleDebugWalk();
  bool get debugWalk => movementController.debugWalk;

  /// Force an immediate synchronous write, bypassing the per-frame
  /// coalesce in [WorldStatePersister]. Use this from lifecycle hooks
  /// (pause, dispose) where the next tick may never run.
  ///
  /// No-ops if [onLoad] hasn't finished yet — [worldStatePersister] is a
  /// late field and the `late` access would throw if the boot-failure
  /// dispose path calls this after a partial `onLoad`.
  void flushWorldState() {
    if (!isLoaded) return;
    worldStatePersister.flush();
  }

  @override
  void onRemove() {
    events.dispose();
    super.onRemove();
  }
}
