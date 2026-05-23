import 'package:flutter/material.dart';

/// A [Page] that materializes as a [ModalBottomSheetRoute] instead of a
/// [PageRoute]. Use with `go_router`'s `pageBuilder` to make a bottom sheet
/// a first-class route — letting the underlying page (and its state) stay
/// alive beneath the sheet.
class ModalBottomSheetPage<T> extends Page<T> {
  const ModalBottomSheetPage({
    required this.builder,
    this.isScrollControlled = false,
    this.useSafeArea = false,
    this.backgroundColor,
    this.isDismissible = true,
    super.key,
    super.name,
  });

  final WidgetBuilder builder;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool isDismissible;

  @override
  Route<T> createRoute(BuildContext context) {
    return ModalBottomSheetRoute<T>(
      settings: this,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      isDismissible: isDismissible,
      builder: builder,
    );
  }
}
