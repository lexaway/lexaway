import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:hive_ce/hive_ce.dart';

import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'persistable.dart';
import 'walk_controller.dart';

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  // One tile at 4x scale = 64px. Walk it in ~0.8s.
  static const double walkSpeed = 80;
  static const double walkTarget = 16 * pixelScale;
  static const double cloudDrift = 1.5;

  final Box? hiveBox;
  String _locale;

  LexawayGame({this.hiveBox, String locale = 'en'}) : _locale = locale;

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
  late WalkController walkController;

  /// Components with persistent state, restored/saved in order.
  final List<Persistable> _persistables = [];

  Function(int value)? onCoinCollected;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final parallaxHeight = size.y * groundLevel + 16 * pixelScale;
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

    add(ground);
    add(coinManager);

    player = Player()..priority = 2;
    add(player);

    speechBubble = SpeechBubble()..priority = 3;
    add(speechBubble);

    walkController = WalkController();
    add(walkController);

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);
  }

  void correctAnswer({required int streak, required String answer}) {
    walkController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    walkController.wrongAnswer();
  }

  void _restoreWorldState() {
    final saved = hiveBox?.get('world') as Map?;
    if (saved == null) return;
    for (final p in _persistables) {
      final data = saved[p.saveKey];
      if (data != null) {
        p.restoreState(Map<String, dynamic>.from(data as Map));
      }
    }
  }

  /// Save current world state to Hive. Called after walk completion,
  /// coin collection, and on app lifecycle events.
  void saveWorldState() {
    if (hiveBox == null) return;
    final state = <String, dynamic>{};
    for (final p in _persistables) {
      state[p.saveKey] = p.saveState();
    }
    hiveBox!.put('world', state);
  }
}
