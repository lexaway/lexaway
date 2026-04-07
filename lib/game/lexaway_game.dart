import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/hive_keys.dart';
import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/entity_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'components/wind_lines.dart';
import 'persistable.dart';
import 'movement_controller.dart';

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const int worldStateVersion = 1;
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  // Three tiles at 4x scale = 192px. Walk them in ~2.4s.
  static const double walkSpeed = 80;
  static const double walkTarget = 3 * 16 * pixelScale;
  static const double cloudDrift = 1.5;

  final Box? hiveBox;
  final String characterPath;
  String _locale;

  LexawayGame({
    this.hiveBox,
    String locale = 'en',
    required this.characterPath,
  }) : _locale = locale;

  String get locale => _locale;
  set locale(String value) {
    if (value == _locale) return;
    _locale = value;
    SpeechMessages.load(value);
  }

  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;
  late EntityManager entityManager;
  late WindLines windLines;
  late MovementController movementController;

  /// Components with persistent state, restored/saved in order.
  final List<Persistable> _persistables = [];

  Function(int value)? onCoinCollected;
  Function(int steps)? onStepTaken;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    parallaxComponent = await loadParallaxComponent(
      [
        ParallaxImageData('parallax/sky.png'),
        ParallaxImageData('parallax/clouds_far.png'),
        ParallaxImageData('parallax/clouds_near.png'),
        ParallaxImageData('parallax/hills.png'),
        ParallaxImageData('parallax/foreground.png'),
      ],
      baseVelocity: Vector2.zero(),
      velocityMultiplierDelta: Vector2(1.4, 0),
      fill: LayerFill.height,
      filterQuality: FilterQuality.none,
      size: Vector2(size.x, parallaxHeight),
    );
    add(parallaxComponent);

    ground = Ground()..priority = 1;
    coinManager = CoinManager()
      ..priority = 1
      ..onCoinCollected = (value) => onCoinCollected?.call(value);

    // Register persistable components in restore order
    // (ground first so coinManager sees the correct scrollOffset).
    _persistables.addAll([ground, coinManager]);
    _restoreWorldState();

    entityManager = EntityManager()..priority = 1;

    add(ground);
    add(entityManager);
    add(coinManager);

    player = Player(spritePath: characterPath)..priority = 2;
    await add(player);

    // Little dino scans the horizon when first dropped into the world
    player.play(DinoAnim.scan);

    windLines = WindLines()..priority = 2;
    add(windLines);

    speechBubble = SpeechBubble()..priority = 3;
    add(speechBubble);

    movementController = MovementController()
      ..onStepTaken = (steps) => onStepTaken?.call(steps);
    add(movementController);

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Gentle cloud drift independent of player movement
    final layers = parallaxComponent.parallax!.layers;
    layers[1].update(Vector2(cloudDrift * dt, 0), dt);
    layers[2].update(Vector2(cloudDrift * 1.8 * dt, 0), dt);
  }

  void correctAnswer({required int streak, required String answer}) {
    movementController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    movementController.wrongAnswer();
  }

  /// True when saved world data is from a newer app version we can't read.
  /// Prevents [saveWorldState] from overwriting it with stale v1 data.
  bool _worldReadOnly = false;

  void _restoreWorldState() {
    try {
      final saved = hiveBox?.get(HiveKeys.world) as Map?;
      if (saved == null) return;

      final version = saved['_version'] as int? ?? 1;
      if (version > worldStateVersion) {
        _worldReadOnly = true;
        return;
      }

      // --- future migrations go here ---
      // if (version < 2) { ... }

      for (final p in _persistables) {
        final data = saved[p.saveKey];
        if (data != null) {
          p.restoreState(Map<String, dynamic>.from(data as Map));
        }
      }
    } catch (_) {
      // Corrupt data — start fresh rather than crash.
    }
  }

  /// Save current world state to Hive. Called after walk completion,
  /// coin collection, and on app lifecycle events.
  void saveWorldState() {
    if (hiveBox == null || _worldReadOnly) return;
    final state = <String, dynamic>{'_version': worldStateVersion};
    for (final p in _persistables) {
      state[p.saveKey] = p.saveState();
    }
    hiveBox!.put(HiveKeys.world, state);
  }
}
