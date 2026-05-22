import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for "where in the world are we?". Owns the world
/// scroll offset, the per-frame scroll speed, and the world zoom (used by
/// in-world encounters like the claw machine to focus the camera on a
/// world entity without dimming the rest of the scene).
class Camera extends Component {
  final ValueNotifier<double> scrollNotifier;
  final ValueNotifier<double> zoomNotifier;

  Camera({double initialOffset = 0})
      : scrollNotifier = ValueNotifier(initialOffset),
        zoomNotifier = ValueNotifier(1.0);

  double get scrollOffset => scrollNotifier.value;
  set scrollOffset(double v) => scrollNotifier.value = v;

  double get zoom => zoomNotifier.value;
  set zoom(double v) => zoomNotifier.value = v;

  /// Screen-space focus point that the world should scale around. At
  /// zoom == 1 this is unused; at zoom > 1 the world transform anchors
  /// this point so the focus doesn't slide while zooming.
  Vector2 zoomFocus = Vector2.zero();

  double _scrollSpeed = 0;
  _ZoomTween? _zoomTween;

  set scrollSpeed(double speed) => _scrollSpeed = speed;

  /// Tween zoom + focus over [duration]. Resolves when the tween lands.
  Future<void> zoomTo({
    required double target,
    required Vector2 focus,
    required double duration,
    Curve curve = Curves.easeInOut,
  }) {
    final completer = Completer<void>();
    _zoomTween = _ZoomTween(
      fromZoom: zoom,
      toZoom: target,
      fromFocus: zoomFocus.clone(),
      toFocus: focus.clone(),
      duration: duration,
      curve: curve,
      onDone: completer.complete,
    );
    return completer.future;
  }

  @override
  void update(double dt) {
    if (_scrollSpeed != 0) scrollOffset += _scrollSpeed * dt;
    final tween = _zoomTween;
    if (tween != null) {
      _zoomTween = tween.tick(dt, (z, f) {
        zoom = z;
        zoomFocus = f;
      });
    }
  }
}

class _ZoomTween {
  final double fromZoom;
  final double toZoom;
  final Vector2 fromFocus;
  final Vector2 toFocus;
  final double duration;
  final Curve curve;
  final VoidCallback onDone;
  double _elapsed = 0;
  bool _done = false;

  _ZoomTween({
    required this.fromZoom,
    required this.toZoom,
    required this.fromFocus,
    required this.toFocus,
    required this.duration,
    required this.curve,
    required this.onDone,
  });

  _ZoomTween? tick(double dt, void Function(double, Vector2) setter) {
    if (_done) return null;
    _elapsed += dt;
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final v = curve.transform(t);
    final z = fromZoom + (toZoom - fromZoom) * v;
    final fx = fromFocus.x + (toFocus.x - fromFocus.x) * v;
    final fy = fromFocus.y + (toFocus.y - fromFocus.y) * v;
    setter(z, Vector2(fx, fy));
    if (t >= 1.0) {
      _done = true;
      onDone();
      return null;
    }
    return this;
  }
}
