import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A single content-type row within a pack card.
class ContentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sizeText;
  final bool downloaded;
  final double? progress;
  final VoidCallback? onTap;
  final Widget trailing;
  final Widget? leading;
  final String? title;

  const ContentRow({
    super.key,
    required this.icon,
    required this.label,
    required this.sizeText,
    required this.downloaded,
    required this.progress,
    required this.onTap,
    required this.trailing,
    this.leading,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 14),
                  ] else
                    // Indent to align with rows that have a leading badge
                    const SizedBox(width: 58),
                  Icon(icon, color: AppColors.textFaint, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              title!,
                              style: GoogleFonts.pixelifySans(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: AppColors.textPrimary.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            if (sizeText != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                sizeText!,
                                style: TextStyle(
                                  color: AppColors.textPrimary.withValues(alpha: 0.25),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
              // Progress bar
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceBright,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
