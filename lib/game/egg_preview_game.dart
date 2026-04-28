import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';

import '../models/character.dart';
import 'audio_manager.dart';

enum EggPhase { wobble, crack, hatch, reveal }

class EggPreviewGame extends FlameGame {
  final CharacterInfo character;
  VoidCallback? onAllPhasesComplete;

  EggPhase _phase = EggPhase.wobble;
  bool _disposed = false;
  final Completer<void> _loaded = Completer<void>();

  static const double _frameSize = 48;
  static const double _scale = 2.0;

  EggPreviewGame({required this.character});

  EggPhase get phase => _phase;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await _showPhase(EggPhase.wobble);
    _loaded.complete();
  }

  @override
  void onRemove() {
    _disposed = true;
    super.onRemove();
  }

  /// Start the crack → hatch → reveal sequence.
  /// Waits for [onLoad] to finish so we never race with the wobble phase.
  Future<void> startHatchSequence() async {
    await _loaded.future;
    if (_disposed) return;
    _showPhase(EggPhase.crack);
  }

  Future<void> _showPhase(EggPhase phase) async {
    _phase = phase;

    if (phase == EggPhase.crack) {
      AudioManager.instance.playEggCrack();
    } else if (phase == EggPhase.reveal) {
      AudioManager.instance.playHatchChime();
    }

    final assetPath = switch (phase) {
      EggPhase.wobble => character.eggMoveAsset,
      EggPhase.crack => character.eggCrackAsset,
      EggPhase.hatch => character.eggHatchAsset,
      EggPhase.reveal => character.idleAsset,
    };

    final image = await images.load(assetPath);
    if (_disposed) return;

    if (children.isNotEmpty) {
      removeAll(children);
    }

    final spriteSize = Vector2.all(_frameSize * _scale);
    final pos = Vector2(
      (size.x - _frameSize * _scale) / 2,
      (size.y - _frameSize * _scale) / 2,
    );
    final noPaint = Paint()..filterQuality = FilterQuality.none;

    // Wobble shows a static frame; Flutter handles the shake animation.
    if (phase == EggPhase.wobble) {
      final sheet = SpriteSheet(image: image, srcSize: Vector2.all(_frameSize));
      add(SpriteComponent(
        sprite: sheet.getSprite(0, 0),
        size: spriteSize,
        position: pos,
        paint: noPaint,
      ));
      return;
    }

    final frameCount = image.width ~/ _frameSize.toInt();
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2.all(_frameSize),
    );

    final loop = phase == EggPhase.reveal;
    final stepTime = 0.25;
    final animation = sheet.createAnimation(
      row: 0,
      from: 0,
      to: frameCount,
      stepTime: stepTime,
      loop: loop,
    );

    final component = SpriteAnimationComponent(
      animation: animation,
      size: spriteSize,
      position: pos,
      paint: noPaint,
    );
    add(component);

    if (!loop) {
      component.animationTicker!.completed.then((_) {
        if (_disposed) return;
        _advance();
      });
    } else if (phase == EggPhase.reveal) {
      onAllPhasesComplete?.call();
    }
  }

  void _advance() {
    switch (_phase) {
      case EggPhase.crack:
        _showPhase(EggPhase.hatch);
      case EggPhase.hatch:
        _showPhase(EggPhase.reveal);
      case EggPhase.wobble:
      case EggPhase.reveal:
        break;
    }
  }
}
