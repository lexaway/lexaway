import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import '../lexaway_game.dart';

enum DinoAnim {
  idle(file: 'idle.png', stepTime: 0.2, loop: true),
  walk(file: 'move.png', stepTime: 0.1, loop: true),
  scan(file: 'scan.png', stepTime: 0.18),
  jump(file: 'jump.png', stepTime: 0.14),
  dash(file: 'dash.png', stepTime: 0.1, loop: true),
  kick(file: 'kick.png', stepTime: 0.14),
  bite(file: 'bite.png', stepTime: 0.14),
  hurt(file: 'hurt.png', stepTime: 0.16),
  dead(file: 'dead.png', stepTime: 0.2),
  avoid(file: 'avoid.png', stepTime: 0.14);

  final String file;
  final double stepTime;
  final bool loop;

  const DinoAnim({
    required this.file,
    required this.stepTime,
    this.loop = false,
  });
}

class Player extends SpriteAnimationGroupComponent<DinoAnim>
    with HasGameReference<LexawayGame>, CollisionCallbacks {
  static const double _spriteSize = 24;
  static const double _scale = LexawayGame.pixelScale * 1.1;

  final String spritePath;

  /// The "resting" state to return to after a one-shot finishes.
  DinoAnim _restingAnim = DinoAnim.idle;
  bool _playingOneShot = false;

  Player({required this.spritePath});

  bool get isBusy => _playingOneShot;

  @override
  Future<void> onLoad() async {
    final anims = <DinoAnim, SpriteAnimation>{};

    for (final anim in DinoAnim.values) {
      final image = await game.images.load('$spritePath/${anim.file}');
      final frameCount = image.width ~/ _spriteSize.toInt();
      final sheet =
          SpriteSheet(image: image, srcSize: Vector2.all(_spriteSize));
      anims[anim] = sheet.createAnimation(
        row: 0,
        from: 0,
        to: frameCount,
        stepTime: anim.stepTime,
        loop: anim.loop,
      );
    }

    animations = anims;
    current = DinoAnim.idle;
    size = Vector2.all(_spriteSize * _scale);

    // 1/4 from left; +3px nudges feet down past sprite's transparent padding
    final groundTop = game.size.y * LexawayGame.groundLevel;
    position = Vector2(game.size.x * 0.25, groundTop - size.y + 3 * _scale);

    paint = Paint()..filterQuality = FilterQuality.none;

    // Hitbox trimmed to the body (~14×18 in the 24×24 frame), skipping the
    // transparent padding: 3px top, 3px bottom.
    add(
      RectangleHitbox(
        position: Vector2(5 * _scale, 3 * _scale),
        size: Vector2(14 * _scale, 18 * _scale),
      ),
    );
  }

  /// Play a one-shot animation, then return to the current resting state.
  void play(DinoAnim anim, {VoidCallback? onComplete}) {
    if (anim.loop) {
      current = anim;
      _playingOneShot = false;
      return;
    }
    current = anim;
    _playingOneShot = true;
    animationTicker!
      ..reset()
      ..onComplete = () {
        _playingOneShot = false;
        current = _restingAnim;
        onComplete?.call();
      };
  }

  void walk() {
    _restingAnim = DinoAnim.walk;
    if (!_playingOneShot) current = DinoAnim.walk;
  }

  void run() {
    _restingAnim = DinoAnim.dash;
    if (!_playingOneShot) current = DinoAnim.dash;
  }

  void idle() {
    _restingAnim = DinoAnim.idle;
    if (!_playingOneShot) current = DinoAnim.idle;
  }
}
