import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'hud_pill.dart';
import 'pixel_sprite_icon.dart';

class HudBar extends ConsumerWidget {
  const HudBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final coins = ref.watch(coinProvider);

    return Padding(
      padding: EdgeInsets.only(top: topPadding + AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HudPill(
                onTap: () => context.push('/packs'),
                child: const Icon(Icons.language, color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: () => context.push('/collection'),
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  'assets/images/ui/collection_icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () => context.push('/settings'),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: PixelSpriteIcon(
                asset: 'assets/images/ui/button_options_sheet.png',
                frameSize: 24,
                scale: 2,
              ),
            ),
          ),
          const Spacer(),
          HudPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/coins/coin_icon.png',
                  width: 20,
                  height: 20,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
