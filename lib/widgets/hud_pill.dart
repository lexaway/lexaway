import 'package:flutter/material.dart';

/// Pixel-art styled pill used for HUD elements in the streak bar.
class HudPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const HudPill({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/ui/panel_metal_bg.png'),
          centerSlice: Rect.fromLTRB(12, 12, 84, 84),
          filterQuality: FilterQuality.none,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: pill);
    }
    return pill;
  }
}
