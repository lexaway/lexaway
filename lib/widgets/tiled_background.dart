import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum BackgroundTexture {
  scales('texture40'),
  scalesLarge('texture38'),
  scalesFine('texture39'),
  stone('texture25'),
  cobblestone('texture26'),
  castleWall('texture27'),
  brick('texture17'),
  brickSharp('texture30'),
  herringbone('texture19'),
  checkerboard('texture1'),
  diamonds('texture76'),
  chevron('texture66'),
  waves('texture91'),
  eyes('texture128');

  const BackgroundTexture(this.filename);
  final String filename;

  String get assetPath => 'assets/images/textures/$filename.png';
}

/// A full-bleed tiled background that can scroll continuously in any direction.
class TiledBackground extends StatefulWidget {
  const TiledBackground({
    super.key,
    required this.texture,
    this.color = Colors.white,
    this.scale = 2,
    this.scrollDirection = Offset.zero,
    this.scrollSpeed = 20,
  });

  final BackgroundTexture texture;
  final Color color;
  final double scale;

  /// Normalized direction. Use [Offset.zero] for a static background.
  final Offset scrollDirection;

  /// Logical pixels per second.
  final double scrollSpeed;

  @override
  State<TiledBackground> createState() => _TiledBackgroundState();
}

class _TiledBackgroundState extends State<TiledBackground>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  ImageStreamListener? _listener;
  ImageStream? _stream;
  late final Ticker _ticker;
  Offset _offset = Offset.zero;
  Duration _lastTick = Duration.zero;

  bool _reduceMotion = false;

  bool get _shouldAnimate =>
      !_reduceMotion &&
      widget.scrollDirection != Offset.zero &&
      widget.scrollSpeed > 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _ticker = createTicker(_onTick);
    // Start is deferred to didChangeDependencies so we can read MediaQuery.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncTicker();
  }

  @override
  void didUpdateWidget(TiledBackground old) {
    super.didUpdateWidget(old);
    if (old.texture != widget.texture) {
      _disposeImage();
      _loadImage();
    }
    _syncTicker();
  }

  void _syncTicker() {
    if (_shouldAnimate && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!_shouldAnimate && _ticker.isActive) {
      _ticker.stop();
      setState(() => _offset = Offset.zero);
    }
  }

  void _loadImage() {
    final provider = AssetImage(widget.texture.assetPath);
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    _stream!.addListener(_listener!);
  }

  void _disposeImage() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _image = null;
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final dir = widget.scrollDirection / widget.scrollDirection.distance;
    _offset += dir * widget.scrollSpeed * dt;

    // Wrap to tile size so _offset never drifts to precision-loss territory.
    if (_image != null) {
      final tileW = _image!.width * widget.scale;
      final tileH = _image!.height * widget.scale;
      _offset = Offset(_offset.dx % tileW, _offset.dy % tileH);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _disposeImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(
        painter: _TiledPainter(
          image: _image!,
          color: widget.color,
          scale: widget.scale,
          offset: _offset,
        ),
      ),
    );
  }
}

class _TiledPainter extends CustomPainter {
  _TiledPainter({
    required this.image,
    required this.color,
    required this.scale,
    required this.offset,
  });

  final ui.Image image;
  final Color color;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.modulate)
      ..filterQuality = FilterQuality.none;

    final tileW = image.width * scale;
    final tileH = image.height * scale;
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    final ox = offset.dx % tileW;
    final oy = offset.dy % tileH;

    for (var y = -tileH + oy; y < size.height + tileH; y += tileH) {
      for (var x = -tileW + ox; x < size.width + tileW; x += tileW) {
        canvas.drawImageRect(image, src, Rect.fromLTWH(x, y, tileW, tileH),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TiledPainter old) =>
      old.image != image ||
      old.color != color ||
      old.scale != scale ||
      old.offset != offset;
}
