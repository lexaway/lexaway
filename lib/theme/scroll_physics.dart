import 'package:flutter/material.dart';

/// Scroll physics that lets a list pass through overscroll-at-top into the
/// enclosing sheet's drag when [fluidSheetDrag] is true. Without this, a
/// `BouncingScrollPhysics` parent would absorb the overscroll itself.
///
/// Also short-circuits ballistic simulations once they reach the top, so a
/// fling-up-from-near-top hits a clean stop instead of bouncing through the
/// hand-off point.
class OverflowScrollPhysics extends ScrollPhysics {
  const OverflowScrollPhysics({
    super.parent,
    this.fluidSheetDrag = false,
  });

  final bool fluidSheetDrag;

  @override
  OverflowScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      OverflowScrollPhysics(
        parent: buildParent(ancestor),
        fluidSheetDrag: fluidSheetDrag,
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.maxScrollExtent == 0) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (position.maxScrollExtent == 0) return value - position.pixels;
    if (fluidSheetDrag &&
        value < position.minScrollExtent &&
        position.pixels >= position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.maxScrollExtent == 0) return null;
    if (fluidSheetDrag && velocity <= 0) {
      final inner = super.createBallisticSimulation(position, velocity);
      if (inner == null) return null;
      return _ClampedBallisticSimulation(inner, minExtent: position.minScrollExtent);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

class _ClampedBallisticSimulation extends Simulation {
  _ClampedBallisticSimulation(this._inner, {required this.minExtent});
  final Simulation _inner;
  final double minExtent;

  @override
  double x(double time) => _inner.x(time).clamp(minExtent, double.infinity);

  @override
  double dx(double time) => _inner.x(time) <= minExtent ? 0.0 : _inner.dx(time);

  @override
  bool isDone(double time) => _inner.isDone(time) || _inner.x(time) <= minExtent;
}
