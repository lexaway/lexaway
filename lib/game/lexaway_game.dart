import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';

import 'components/ground.dart';
import 'components/player.dart';

class LexawayGame extends FlameGame {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.45;

  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;

  bool _isWalking = false;
  double _walkProgress = 0;

  // One tile at 4x scale = 64px. Walk it in ~0.8s.
  static const double walkSpeed = 80;
  static const double walkTarget = 16 * pixelScale;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF); // Match sky color

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
    add(ground);

    player = Player()..priority = 2;
    add(player);
  }

  void correctAnswer() {
    if (_isWalking) return;
    _isWalking = true;
    _walkProgress = 0;
    player.walk();
    parallaxComponent.parallax!.baseVelocity = Vector2(walkSpeed * 0.1, 0);
    ground.startScrolling(walkSpeed);
  }

  void _stopWalking() {
    _isWalking = false;
    player.idle();
    parallaxComponent.parallax!.baseVelocity = Vector2.zero();
    ground.stopScrolling();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isWalking) {
      _walkProgress += walkSpeed * dt;
      if (_walkProgress >= walkTarget) {
        _stopWalking();
      }
    }
  }

}
