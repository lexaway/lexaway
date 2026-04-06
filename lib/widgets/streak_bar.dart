import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class StreakBar extends ConsumerWidget {
  final VoidCallback onLanguageTap;
  const StreakBar({super.key, required this.onLanguageTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final streak = ref.watch(streakProvider);

    return Padding(
      padding: EdgeInsets.only(top: topPadding + 8, left: 12, right: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onLanguageTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  const Icon(Icons.language, color: Colors.white70, size: 20),
            ),
          ),
          const Spacer(),
          if (streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '\u{1F525} $streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
