import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../data/world_state_repository.dart';
import 'audio_manager.dart';
import 'components/biome_parallax.dart';
import 'components/camera.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'components/weather_overlay.dart';
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
  /// forwards the change to the speech bubble so a Settings change is
  /// picked up while the game is running. If [onLoad] hasn't completed
  /// yet, the new value is stored and picked up when the bubble is
  /// constructed there.
  String get fontFamily => _fontFamily;
  set fontFamily(String value) {
    if (value == _fontFamily) return;
    _fontFamily = value;
    if (isLoaded) _speechBubble.fontFamily = value;
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

  late final WorldMap _worldMap;
  late final Camera _camera;
  late final WorldStreamer _worldStreamer;
  late final WorldStatePersister _worldStatePersister;
  late final BiomeParallax _biomeParallax;
  late final Ground _ground;
  late final WorldRenderer _worldRenderer;
  late final CreatureLayer _creatureLayer;
  late final CoinManager _coinManager;
  late final Player _player;
  late final WindLines _windLines;
  late final WeatherOverlay _weatherOverlay;
  late final SpeechBubble _speechBubble;
  late final MovementController _movementController;

  /// World map, exposed for read-only UI access (the minimap renders from
  /// it). Sibling systems should take a [WorldMap] in their constructor
  /// instead of reaching through here.
  WorldMap get worldMap => _worldMap;

  /// Live scroll offset. Exposed for UI bindings (minimap) and for
  /// downstream creature behaviors that don't fit the constructor-injection
  /// pattern. Sibling systems should take a [Camera] in their constructor.
  double get scrollOffset => _camera.scrollOffset;
  ValueNotifier<double> get scrollNotifier => _camera.scrollNotifier;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final saved = worldStateRepository.load();
    final seed = saved?.seed ?? Random().nextInt(1 << 32);
    final initialOffset = saved?.scrollOffset ?? 0.0;

    final entityFootprints = await loadEntityFootprints();
    _worldMap = WorldGenerator(entityFootprints: entityFootprints)
        .generate(seed);

    _camera = Camera(initialOffset: initialOffset);
    add(_camera);

    // Replay previously-persisted extensions at their original seeds so
    // _worldMap.segments matches the saved scroll offset before any
    // components that read the map come online. [WorldStreamer.extend]
    // is a no-op on the event bus while unmounted, so replay doesn't
    // spuriously dirty the persister.
    _worldStreamer = WorldStreamer(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      entityFootprints: entityFootprints,
    );
    for (var i = 0; i < (saved?.extensions ?? 0); i++) {
      _worldStreamer.extend();
    }

    _worldStatePersister = WorldStatePersister(
      repository: worldStateRepository,
      camera: _camera,
      worldMap: _worldMap,
      worldStreamer: _worldStreamer,
      events: events,
      initialCollectedCoins: saved?.collectedCoins ?? const [],
    );

    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    _biomeParallax = BiomeParallax(
      worldMap: _worldMap,
      initialScrollOffset: initialOffset,
    )..size = Vector2(size.x, parallaxHeight);
    await add(_biomeParallax);

    _ground = Ground(worldMap: _worldMap, camera: _camera)..priority = 1;
    add(_ground);

    _worldRenderer = WorldRenderer(worldMap: _worldMap, camera: _camera)
      ..priority = 1;
    add(_worldRenderer);

    _creatureLayer = CreatureLayer(worldMap: _worldMap, camera: _camera)
      ..priority = 1;
    add(_creatureLayer);

    // CoinManager shares the collectedCoins Set with the persister so its
    // spawn loop can dedup against saved pickups; the persister owns the
    // mutation lifecycle via its CoinCollected subscription.
    _coinManager = CoinManager(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      collectedCoins: _worldStatePersister.collectedCoins,
    )..priority = 1;
    add(_coinManager);

    _player = Player(spritePath: characterPath)..priority = 2;
    await add(_player);
    _player.play(DinoAnim.scan);

    _windLines = WindLines()..priority = 2;
    add(_windLines);

    // Weather sits between player/wind (priority 2) and speech bubble — snow
    // falls in front of the dino but never obscures dialogue.
    _weatherOverlay = WeatherOverlay(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      initialScrollOffset: initialOffset,
    )..priority = 3;
    await add(_weatherOverlay);

    _speechBubble = SpeechBubble(follow: _player, fontFamily: _fontFamily)
      ..priority = 4;
    add(_speechBubble);

    _movementController = MovementController(
      camera: _camera,
      worldMap: _worldMap,
      events: events,
    );
    add(_movementController);

    add(AudioCueController(events: events));
    add(ScrollController(
      camera: _camera,
      biomeParallax: _biomeParallax,
      worldMap: _worldMap,
      events: events,
    ));
    add(WindController(windLines: _windLines, events: events));
    add(AnimationController(player: _player, events: events));
    add(DialogueController(
      bubble: _speechBubble,
      events: events,
      localeGetter: () => _locale,
    ));
    add(_worldStreamer);
    // Persister is added AFTER coinManager so its CoinCollected handler
    // runs second. CoinManager's handler reads the still-alive Coin's
    // sprite state to spawn the fly effect; the persister then mutates
    // collectedCoins. Reordering would still work today (sync emit, both
    // handlers run before the next frame), but the trajectory would be
    // first-frame race-prone — keep them in this order.
    add(_worldStatePersister);

    events.on<WorldExtended>().listen((_) => _loadNewBiomes());

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);

    // Persist the seed on first run. The persister isn't mounted yet so
    // its per-frame dirty drain hasn't started — flush() writes directly.
    if (saved == null) _worldStatePersister.flush();
  }

  void _loadNewBiomes() {
    for (final seg in _worldMap.segments) {
      _ground.ensureBiomeLoaded(seg.biome);
      _worldRenderer.ensureBiomeLoaded(seg.biome);
      _creatureLayer.ensureBiomeLoaded(seg.biome);
      _biomeParallax.ensureBiomeLoaded(seg.biome);
      _weatherOverlay.ensureBiomeLoaded(seg.biome);
    }
  }

  void correctAnswer({required int streak, required String answer}) {
    _movementController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    _movementController.wrongAnswer();
  }

  /// Toggle debug mode: dino walks continuously without answering.
  void toggleDebugWalk() => _movementController.toggleDebugWalk();
  bool get debugWalk => _movementController.debugWalk;

  /// Finish any in-progress walk immediately (no animation). Called from
  /// app-lifecycle teardown so the dino doesn't get caught mid-stride.
  void finishMovement() => _movementController.finishMovement();

  /// Force an immediate synchronous write, bypassing the per-frame
  /// coalesce in [WorldStatePersister]. Use this from lifecycle hooks
  /// (pause, dispose) where the next tick may never run.
  ///
  /// No-ops if [onLoad] hasn't finished yet — the persister is a `late`
  /// field and the access would throw if the boot-failure dispose path
  /// calls this after a partial `onLoad`.
  void flushWorldState() {
    if (!isLoaded) return;
    _worldStatePersister.flush();
  }

  @override
  void onRemove() {
    events.dispose();
    super.onRemove();
  }
}
