import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/audio_manager.dart';
import '../theme/app_spacing.dart';
import '../theme/scroll_physics.dart';
import '../utils/route_pages.dart';

class _SheetScrollBehavior extends ScrollBehavior {
  const _SheetScrollBehavior(this._parent, {required this.fluidSheetDrag});
  final ScrollBehavior _parent;
  final bool fluidSheetDrag;

  // Disable the framework's drag devices so all vertical drags route through
  // the sheet's own GestureDetector, where the hand-off logic lives.
  @override
  Set<PointerDeviceKind> get dragDevices => {};

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => OverflowScrollPhysics(
        parent: _parent.getScrollPhysics(context),
        fluidSheetDrag: fluidSheetDrag,
      );
}

/// A draggable bottom sheet that hands off vertical drags between its
/// content scrollable and the sheet itself. With [fluidSheetDrag] enabled,
/// scrolling a list to its top and continuing to drag down pulls the sheet
/// closed in one continuous motion; flinging a list to the top transfers
/// inertia into a sheet bounce.
///
/// Use [LexawayBottomSheet.goRoute] from a `go_router` `pageBuilder` to make
/// the sheet a proper route on the navigator stack.
class LexawayBottomSheet extends StatefulWidget {
  const LexawayBottomSheet({
    super.key,
    required this.body,
    this.appBarBuilder,
    this.showDragBar = false,
    this.fluidSheetDrag = false,
    this.sheetSize = 1.0,
    this.backgroundColor,
    this.borderRadius,
    this.topBorderColor,
  });

  /// Convenience factory that wraps this widget in a [ModalBottomSheetPage]
  /// with the correct defaults for `go_router`'s `pageBuilder`.
  static ModalBottomSheetPage<T> goRoute<T>({
    /// Pass in `state.pageKey`.
    required LocalKey key,
    String? name,
    required Widget body,
    WidgetBuilder? appBarBuilder,
    bool showDragBar = false,
    bool fluidSheetDrag = true,
    double sheetSize = 1.0,
    Color? backgroundColor,
    double? borderRadius,
    Color? topBorderColor,
  }) {
    return ModalBottomSheetPage<T>(
      key: key,
      name: name,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LexawayBottomSheet(
        body: body,
        appBarBuilder: appBarBuilder,
        showDragBar: showDragBar,
        fluidSheetDrag: fluidSheetDrag,
        sheetSize: sheetSize,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        topBorderColor: topBorderColor,
      ),
    );
  }

  final Widget body;

  /// Optional custom bar rendered above the body. The bar's surface is a
  /// drag handle for the sheet. If null, no bar is rendered.
  final WidgetBuilder? appBarBuilder;

  /// Show a small drag indicator pip above the bar.
  final bool showDragBar;

  /// When true, vertical drags transition fluidly between scrolling the body
  /// and dragging the sheet, in both directions. A fling-to-top inside the
  /// body also transfers into a sheet bounce.
  final bool fluidSheetDrag;

  /// Fractional height of the sheet (0.0–1.0). Sets both initial and maximum
  /// size; can be dragged down to dismiss.
  final double sheetSize;

  /// Background color of the sheet's outer container. Defaults to transparent
  /// so callers can supply their own surface via [body].
  final Color? backgroundColor;

  /// Rounded top corners; null/0 means square corners.
  final double? borderRadius;

  /// Optional 1px line along the top edge of the sheet.
  final Color? topBorderColor;

  @override
  State<LexawayBottomSheet> createState() => _LexawayBottomSheetState();
}

class _LexawayBottomSheetState extends State<LexawayBottomSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ScrollController _bodyScrollController = ScrollController();
  DragStartDetails? _lastDragStart;
  Drag? _contentDrag;
  bool? _draggingSheet;
  bool _dismissing = false;
  double _approachVelocity = 0;

  // -- Dismiss --
  static const _flingDismissVelocity = 300.0;
  static const _dismissSizeThreshold = 0.5;
  static const _dismissedSize = 0.01;

  // -- Sheet animations --
  static const _settleAnimDuration = Duration(milliseconds: 200);

  // -- Fluid bounce animation --
  static const _bounceDipDuration = Duration(milliseconds: 80);
  static const _bounceReturnDuration = Duration(milliseconds: 160);
  static const _bounceDipMax = 0.07;

  // -- Scroll-to-top detection --
  static const _approachTrackingRange = 15.0;
  static const _approachMinSpeed = 10.0;
  static const _approachDismissSpeed = 55.0;
  static const _bounceEndTolerance = 4.0;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    AudioManager.instance.playSheetOpen();
  }

  @override
  void dispose() {
    // Universal "sheet dismissed" cue — covers drag-to-close, tap-outside,
    // and the close button, since they all tear the route down through here.
    AudioManager.instance.playSheetClose();
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  void _onSheetSizeChanged() {
    if (_sheetController.isAttached && _sheetController.size <= _dismissedSize) {
      _dismiss();
    }
  }

  bool get _isContentAtTop {
    if (!_bodyScrollController.hasClients) return true;
    return _bodyScrollController.offset <= 0;
  }

  void _dismiss() {
    if (_dismissing || !Navigator.of(context).canPop()) return;
    _dismissing = true;
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0,
        duration: _settleAnimDuration,
        curve: Curves.easeIn,
      );
    }
    Navigator.of(context).pop();
  }

  void _moveSheet(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final totalHeight = (context.findRenderObject()! as RenderBox).size.height;
    final newSize = (_sheetController.size - details.delta.dy / totalHeight)
        .clamp(0.0, widget.sheetSize);
    _sheetController.jumpTo(newSize);
  }

  void _settleSheet(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final flung = details.velocity.pixelsPerSecond.dy > _flingDismissVelocity;
    if (flung ||
        _sheetController.size < widget.sheetSize * _dismissSizeThreshold) {
      _dismiss();
    } else {
      _sheetController.animateTo(
        widget.sheetSize,
        duration: _settleAnimDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _snapBack() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        widget.sheetSize,
        duration: _settleAnimDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _animateSheetBounce(double speed) {
    if (!_sheetController.isAttached || _dismissing) return;
    if (speed >= _approachDismissSpeed) {
      _dismiss();
      return;
    }
    final t = (speed - _approachMinSpeed) /
        (_approachDismissSpeed - _approachMinSpeed);
    final dip = (widget.sheetSize - t.clamp(0.0, 1.0) * _bounceDipMax)
        .clamp(0.0, widget.sheetSize);
    _sheetController
        .animateTo(dip, duration: _bounceDipDuration, curve: Curves.easeOut)
        .then((_) {
      if (mounted && _sheetController.isAttached && !_dismissing) {
        _sheetController.animateTo(
          widget.sheetSize,
          duration: _bounceReturnDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startDrag(DragStartDetails _) {}
  void _updateDrag(DragUpdateDetails details) => _moveSheet(details);
  void _endDrag(DragEndDetails details) => _settleSheet(details);
  void _cancelDrag() => _snapBack();

  void _handleBodyDragStart(DragStartDetails details) {
    _lastDragStart = details;
    _draggingSheet = null;
    _approachVelocity = 0;
  }

  void _handleBodyDragUpdate(DragUpdateDetails details) {
    if (widget.fluidSheetDrag) {
      _handleBodyDragUpdateFluid(details);
    } else {
      _handleBodyDragUpdateInnerBounce(details);
    }
  }

  // Decision made once at gesture start; no mid-gesture hand-offs.
  void _handleBodyDragUpdateInnerBounce(DragUpdateDetails details) {
    if (_draggingSheet == null) {
      final hasScrollable = _bodyScrollController.hasClients;
      if (_isContentAtTop && details.delta.dy > 0) {
        _draggingSheet = true;
      } else if (!hasScrollable) {
        _draggingSheet = true;
      } else {
        _draggingSheet = false;
        _contentDrag = _bodyScrollController.position
            .drag(_lastDragStart!, () => _contentDrag = null);
      }
    }
    if (_draggingSheet!) {
      _moveSheet(details);
    } else {
      _contentDrag?.update(details);
    }
  }

  // Mid-gesture hand-offs in both directions for a continuous feel.
  void _handleBodyDragUpdateFluid(DragUpdateDetails details) {
    if (_draggingSheet == null) {
      final hasScrollable = _bodyScrollController.hasClients;
      if (!hasScrollable) {
        _draggingSheet = true;
      } else {
        _draggingSheet = false;
        _contentDrag = _bodyScrollController.position
            .drag(_lastDragStart!, () => _contentDrag = null);
      }
    }

    if (_draggingSheet == false) {
      if (_isContentAtTop && details.delta.dy > 0) {
        _contentDrag?.cancel();
        _contentDrag = null;
        _draggingSheet = true;
      } else {
        _contentDrag?.update(details);
        return;
      }
    }

    // Sheet is back at full size and user drags up — hand back to content.
    if (_sheetController.isAttached &&
        _sheetController.size >= widget.sheetSize &&
        details.delta.dy < 0 &&
        _bodyScrollController.hasClients) {
      _draggingSheet = false;
      _contentDrag = _bodyScrollController.position
          .drag(_lastDragStart!, () => _contentDrag = null);
      _contentDrag?.update(details);
      return;
    }

    _moveSheet(details);
  }

  void _handleBodyDragEnd(DragEndDetails details) {
    if (_draggingSheet ?? false) {
      _settleSheet(details);
    } else {
      _contentDrag?.end(details);
    }
    _draggingSheet = null;
  }

  void _handleBodyDragCancel() {
    if (_draggingSheet ?? false) {
      _snapBack();
    } else {
      _contentDrag?.cancel();
    }
    _draggingSheet = null;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta < 0 &&
          notification.metrics.pixels <= _approachTrackingRange) {
        if (delta.abs() > _approachVelocity) _approachVelocity = delta.abs();
      }
    } else if (notification is ScrollEndNotification &&
        notification.metrics.pixels <= _bounceEndTolerance &&
        _approachVelocity > _approachMinSpeed &&
        _draggingSheet == null) {
      final speed = _approachVelocity;
      _approachVelocity = 0;
      _animateSheetBounce(speed);
    } else if (notification is ScrollStartNotification) {
      _approachVelocity = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(widget.borderRadius ?? 0);
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: widget.sheetSize,
      minChildSize: 0,
      maxChildSize: widget.sheetSize,
      snap: true,
      snapSizes: const [],
      snapAnimationDuration: const Duration(milliseconds: 100),
      builder: (context, scrollController) {
        return TapRegion(
          onTapOutside: (_) => Navigator.of(context).maybePop(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.vertical(top: radius),
              border: widget.topBorderColor != null
                  ? Border(top: BorderSide(color: widget.topBorderColor!))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: radius),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight < 1) {
                      return const SizedBox.shrink();
                    }
                    return ClipRect(
                      child: Column(
                        children: [
                          if (widget.showDragBar)
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragStart: _startDrag,
                              onVerticalDragUpdate: _updateDrag,
                              onVerticalDragEnd: _endDrag,
                              onVerticalDragCancel: _cancelDrag,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 48,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).hintColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.appBarBuilder != null)
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragStart: _startDrag,
                              onVerticalDragUpdate: _updateDrag,
                              onVerticalDragEnd: _endDrag,
                              onVerticalDragCancel: _cancelDrag,
                              child: widget.appBarBuilder!(context),
                            ),
                          Expanded(
                            child: Stack(
                              children: [
                                // Invisible scrollable that the
                                // DraggableScrollableSheet's gesture system
                                // treats as the body. Real scrolling happens
                                // in the body widget below via the primary
                                // scroll controller.
                                IgnorePointer(
                                  child: SingleChildScrollView(
                                    controller: scrollController,
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onVerticalDragStart: _handleBodyDragStart,
                                  onVerticalDragUpdate: _handleBodyDragUpdate,
                                  onVerticalDragEnd: _handleBodyDragEnd,
                                  onVerticalDragCancel: _handleBodyDragCancel,
                                  child: ScrollConfiguration(
                                    behavior: _SheetScrollBehavior(
                                      ScrollConfiguration.of(context),
                                      fluidSheetDrag: widget.fluidSheetDrag,
                                    ),
                                    child: NotificationListener<ScrollNotification>(
                                      onNotification: widget.fluidSheetDrag
                                          ? _onScrollNotification
                                          : null,
                                      child: PrimaryScrollController(
                                        controller: _bodyScrollController,
                                        child: widget.body,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
