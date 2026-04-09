import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import '../widgets/tiled_background.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  late final Timer _failsafe;

  @override
  void initState() {
    super.initState();
    // If we're still here after 3 seconds, kick the provider to unstick.
    _failsafe = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.invalidate(activePackProvider);
    });
  }

  @override
  void dispose() {
    _failsafe.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Stack(
        children: [
          TiledBackground(
            texture: BackgroundTexture.scales,
            color: AppColors.scaffold,
            scale: 6,
            scrollDirection: const Offset(1, 1),
            scrollSpeed: 10,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LEXAWAY',
                  style: GoogleFonts.pixelifySans(
                    fontSize: 48,
                    color: AppColors.accent,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                const _WalkingDino(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkingDino extends StatefulWidget {
  const _WalkingDino();

  @override
  State<_WalkingDino> createState() => _WalkingDinoState();
}

class _WalkingDinoState extends State<_WalkingDino>
    with SingleTickerProviderStateMixin {
  static const _frameSize = 24.0;
  static const _scale = 4.0;
  static const _stepTime = 0.1;
  static const _spritePath =
      'assets/images/characters/female/doux/base/move.png';

  ui.Image? _image;
  int _frameCount = 0;
  int _currentFrame = 0;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _ticker = createTicker(_onTick)..start();
  }

  void _loadImage() {
    final stream =
        const AssetImage(_spritePath).resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _image = info.image;
          _frameCount = info.image.width ~/ _frameSize.toInt();
        });
      }
    }));
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _elapsed += dt;

    if (_frameCount > 0 && _elapsed >= _stepTime) {
      _elapsed -= _stepTime;
      setState(() => _currentFrame = (_currentFrame + 1) % _frameCount);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displaySize = _frameSize * _scale;
    if (_image == null) {
      return SizedBox(width: displaySize, height: displaySize);
    }
    return CustomPaint(
      size: Size(displaySize, displaySize),
      painter: _DinoPainter(
        image: _image!,
        frame: _currentFrame,
        frameSize: _frameSize,
      ),
    );
  }
}

class _DinoPainter extends CustomPainter {
  const _DinoPainter({
    required this.image,
    required this.frame,
    required this.frameSize,
  });

  final ui.Image image;
  final int frame;
  final double frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(frame * frameSize, 0, frameSize, frameSize);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_DinoPainter old) =>
      old.frame != frame || old.image != image;
}
