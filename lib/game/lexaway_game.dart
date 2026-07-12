import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';

import '../data/collectibles/collectible.dart';
import '../data/world_state_repository.dart';
import 'audio_manager.dart';
import 'claw_machine/cabinet.dart';
import 'claw_machine/claw_session.dart';
import 'components/biome_parallax.dart';
import 'components/camera.dart';
import 'components/claw_machine.dart';
import 'components/claw_machine_manager.dart';
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
import 'systems/streak_vfx_controller.dart';
import 'systems/wind_controller.dart';
import 'systems/world_state_persister.dart';
import 'systems/world_streamer.dart';
import 'world/creature_layer.dart';
import 'world/entity_footprints.dart';
import 'world/world_generator.dart';
import 'world/world_map.dart';
import 'world/world_renderer.dart';

/// Outcome of a single claw attempt, returned by [LexawayGame.startClawEncounter]
/// and [LexawayGame.restartClawSession]. Carries the prize identity so the
/// screen layer can show what the player won (and add it to their inventory).
class ClawAttemptResult {
  final bool won;
  final int spheresWon;
  final Collectible? prize;
  const ClawAttemptResult({
    required this.won,
    required this.spheresWon,
    required this.prize,
  });
}

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  /// Tiles of ground covered by a single (non-streak) correct answer.
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
  late final ClawMachineManager _clawMachineManager;
  late final Player _player;
  late final WindLines _windLines;
  late final WeatherOverlay _weatherOverlay;
  late final SpeechBubble _speechBubble;
  late final MovementController _movementController;

  /// Visual world subtree. Everything that renders sits under this so the
  /// camera's zoom can be applied as a single scale-around-focus transform
  /// (used by the in-world claw machine encounter — see [startClawEncounter]).
  /// Logic-only controllers (event subscribers, persister, streamer) live on
  /// the game directly so they aren't affected by the transform.
  late final PositionComponent _worldRoot;

  /// World map, exposed for read-only UI access (the minimap renders from
  /// it). Sibling systems should take a [WorldMap] in their constructor
  /// instead of reaching through here.
  WorldMap get worldMap => _worldMap;

  /// The biome currently under the screen centre — the same probe
  /// [ScrollController] uses to detect crossings. Exposed so the screen can
  /// start the right ambient bed on load, before any [BiomeChanged] fires.
  BiomeType get currentBiome =>
      _worldMap.biomeAt(_camera.scrollOffset + size.x / 2);

  /// Live scroll offset. Exposed for UI bindings (minimap) and for
  /// downstream creature behaviors that don't fit the constructor-injection
  /// pattern. Sibling systems should take a [Camera] in their constructor.
  double get scrollOffset => _camera.scrollOffset;
  ValueNotifier<double> get scrollNotifier => _camera.scrollNotifier;
  double get zoomBlend => _camera.zoomBlend;

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

    _worldRoot = PositionComponent();
    add(_worldRoot);

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
      initialUsedClawMachines: saved?.usedClawMachines ?? const [],
    );

    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    _biomeParallax = BiomeParallax(
      worldMap: _worldMap,
      initialScrollOffset: initialOffset,
    )..size = Vector2(size.x, parallaxHeight);
    await _worldRoot.add(_biomeParallax);

    _ground = Ground(worldMap: _worldMap, camera: _camera)..priority = 1;
    _worldRoot.add(_ground);

    _worldRenderer = WorldRenderer(worldMap: _worldMap, camera: _camera)
      ..priority = 1;
    _worldRoot.add(_worldRenderer);

    _creatureLayer = CreatureLayer(worldMap: _worldMap, camera: _camera)
      ..priority = 1;
    _worldRoot.add(_creatureLayer);

    // CoinManager shares the collectedCoins Set with the persister so its
    // spawn loop can dedup against saved pickups; the persister owns the
    // mutation lifecycle via its CoinCollected subscription.
    _coinManager = CoinManager(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      collectedCoins: _worldStatePersister.collectedCoins,
    )..priority = 1;
    _worldRoot.add(_coinManager);

    // Same shared-Set pattern as CoinManager — the persister owns mutation,
    // the manager reads to dedup spawns.
    _clawMachineManager = ClawMachineManager(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      usedClawMachines: _worldStatePersister.usedClawMachines,
    )..priority = 1;
    _worldRoot.add(_clawMachineManager);

    _player = Player(spritePath: characterPath)..priority = 2;
    await _worldRoot.add(_player);
    _player.play(DinoAnim.scan);

    _windLines = WindLines()..priority = 2;
    _worldRoot.add(_windLines);

    // Weather sits between player/wind (priority 2) and speech bubble — snow
    // falls in front of the dino but never obscures dialogue.
    _weatherOverlay = WeatherOverlay(
      worldMap: _worldMap,
      camera: _camera,
      events: events,
      initialScrollOffset: initialOffset,
    )..priority = 3;
    await _worldRoot.add(_weatherOverlay);

    _speechBubble = SpeechBubble(follow: _player, fontFamily: _fontFamily)
      ..priority = 4;
    _worldRoot.add(_speechBubble);

    _movementController = MovementController(
      camera: _camera,
      worldMap: _worldMap,
      events: events,
    );
    add(_movementController);

    add(AudioCueController(events: events));
    add(StreakVfxController(events: events, player: _player));
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

  @override
  void update(double dt) {
    super.update(dt);
    // Apply the camera zoom as a scale-about-focus transform on the world
    // root. At zoom == 1 this is identity (offset zero, scale 1) — bit-
    // identical to pre-refactor rendering.
    final z = _camera.zoom;
    if (z == 1.0) {
      _worldRoot.scale.setAll(1.0);
      _worldRoot.position.setZero();
    } else {
      _worldRoot.scale.setAll(z);
      _worldRoot.position
        ..x = _camera.zoomFocus.x * (1 - z)
        ..y = _camera.zoomFocus.y * (1 - z);
    }
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

  /// Pause the walk for an encounter (claw machine, etc.) without losing
  /// in-flight distance. Resume restores it.
  void pauseMovement() => _movementController.pause();
  void resumeMovement() => _movementController.resume();

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

  // ─── Claw machine encounter ────────────────────────────────────────

  /// Begin an in-world encounter with the cabinet at [itemIndex]. The
  /// camera zooms into the cabinet, a [ClawSessionComponent] is mounted
  /// onto it, and this future resolves once the player's attempt has
  /// played out. The session components remain on-screen (zoomed in) so
  /// the result splash can sit over them — call [endClawEncounter] to
  /// zoom back out and tear the session down.
  Future<ClawAttemptResult> startClawEncounter(
    int itemIndex, {
    double safeBottomInset = 0,
  }) async {
    final cabinet = _clawMachineManager.activeItems[itemIndex];
    if (cabinet == null) {
      // Cabinet scrolled off or was already culled — surface a benign
      // result so the screen flow can finish without hanging.
      return const ClawAttemptResult(won: false, spheresWon: 0, prize: null);
    }

    _speechBubble.muted = true;

    final result = _runSession(cabinet);

    // Fit zoom: cabinet fills ~85% of the smaller viewport dimension.
    final targetZoom = min(
          size.x / ClawCabinet.cabW,
          size.y / ClawCabinet.cabH,
        ) *
        0.85;
    // Frame the cabinet so its bottom sits just above the bottom of the
    // viewport (cabinet sky/parallax shows above; ground hides below).
    // The world transform is `screen = focus + (world - focus) * z`, so
    // for a desired screen anchor S of a world point P at zoom z:
    //   focus = (S - P * z) / (1 - z)
    // Anchor x: cabinet.center.x → screen center. Anchor y: cabinet
    // bottom → screen bottom minus a small margin, plus an extra lift so
    // the cabinet clears the home indicator / gesture bar (capped at 64px
    // so larger safe areas don't push the cabinet too high).
    const bottomMargin = 16.0;
    final extraLift = min(safeBottomInset, 64.0);
    final cabCenterX = cabinet.position.x + cabinet.size.x / 2;
    final cabBottomY = cabinet.position.y + cabinet.size.y;
    final focus = Vector2(
      (size.x / 2 - cabCenterX * targetZoom) / (1 - targetZoom),
      (size.y - bottomMargin - extraLift - cabBottomY * targetZoom) /
          (1 - targetZoom),
    );
    await _camera.zoomTo(
      target: targetZoom,
      focus: focus,
      duration: 0.6,
      curve: Curves.easeInOut,
    );

    return result;
  }

  /// Tear down the current session and start a fresh one on the same
  /// cabinet without touching the camera. Used by the result dialog's
  /// "Try again" button so a retry feels instant — no zoom-out/in flash.
  Future<ClawAttemptResult> restartClawSession(int itemIndex) async {
    final cabinet = _clawMachineManager.activeItems[itemIndex];
    if (cabinet == null) {
      return const ClawAttemptResult(won: false, spheresWon: 0, prize: null);
    }
    cabinet.endSession();
    return _runSession(cabinet);
  }

  /// Start a session on [cabinet] and resolve once the attempt has played
  /// out. Shared by [startClawEncounter] and [restartClawSession].
  Future<ClawAttemptResult> _runSession(ClawMachine cabinet) {
    final completer = Completer<ClawAttemptResult>();
    cabinet.startSession(
      onResultReady: ({
        required bool won,
        required int spheresWon,
        Collectible? prize,
      }) {
        if (!completer.isCompleted) {
          completer.complete(
            ClawAttemptResult(won: won, spheresWon: spheresWon, prize: prize),
          );
        }
      },
    );
    return completer.future;
  }

  /// Tear down the active encounter and zoom back out to 1.0. Safe to
  /// call even if the session is already gone.
  Future<void> endClawEncounter() async {
    await _camera.zoomTo(
      target: 1.0,
      focus: _camera.zoomFocus,
      duration: 0.6,
      curve: Curves.easeInOut,
    );
    // Find any cabinet that still has a live session and shut it down.
    for (final cabinet in _clawMachineManager.activeItems.values) {
      if (cabinet.session != null) {
        cabinet.endSession();
        break;
      }
    }
    _speechBubble.muted = false;
  }

  @override
  void onRemove() {
    events.dispose();
    super.onRemove();
  }
}
