import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import 'hud_pill.dart';

class StreakBar extends ConsumerWidget {
  const StreakBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final coins = ref.watch(coinProvider);

    return Padding(
      padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 16),
      child: Row(
        children: [
          HudPill(
            onTap: () => context.push('/packs'),
            child: const Icon(Icons.language, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 8),
          HudPill(
            onTap: () => context.push('/settings'),
            child: const Icon(Icons.settings, color: AppColors.textSecondary, size: 20),
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
                const SizedBox(width: 4),
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
