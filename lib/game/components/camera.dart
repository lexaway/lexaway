import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for "where in the world are we?". Owns the world
/// scroll offset and the per-frame scroll speed. Pulled out of [Ground] so
/// rendering doesn't conflate with camera state — and so sibling systems
/// can take a [Camera] reference without dragging the entire terrain
/// renderer along with it.
class Camera extends Component {
  final ValueNotifier<double> scrollNotifier;

  Camera({double initialOffset = 0})
      : scrollNotifier = ValueNotifier(initialOffset);

  double get scrollOffset => scrollNotifier.value;
  set scrollOffset(double v) => scrollNotifier.value = v;

  double _scrollSpeed = 0;

  void startScrolling(double speed) => _scrollSpeed = speed;
  void stopScrolling() => _scrollSpeed = 0;

  @override
  void update(double dt) {
    if (_scrollSpeed != 0) scrollOffset += _scrollSpeed * dt;
  }
}
