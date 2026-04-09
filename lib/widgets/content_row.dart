import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single content-type row within a pack card.
///
/// Left side shows status: content icon → spinner → checkmark.
/// Right side shows action: download button → nothing → trash icon.
class ContentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? sizeText;
  final bool downloaded;
  final bool updateAvailable;
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;
  final void Function(BuildContext context)? onSwap;

  const ContentRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.sizeText,
    required this.downloaded,
    this.updateAvailable = false,
    required this.progress,
    this.onDownload,
    this.onUpdate,
    this.onDelete,
    this.onSwap,
  });

  bool get _isDownloading => progress != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              // -- Left: status indicator (44px to match header badge) --
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: _isDownloading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress! > 0 ? progress : null,
                            color: AppColors.tileTextFaint,
                            backgroundColor: AppColors.tileText.withValues(alpha: 0.08),
                          ),
                        )
                      : downloaded && updateAvailable
                          ? Icon(
                              Icons.arrow_upward,
                              color: AppColors.accent,
                              size: 20,
                            )
                          : downloaded
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                )
                              : Icon(
                                  icon,
                                  color: AppColors.tileTextFaint,
                                  size: 20,
                                ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // -- Label + size --
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.tileTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (sizeText != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            sizeText!,
                            style: const TextStyle(
                              color: AppColors.tileTextFaint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.tileTextFaint,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // -- Right: action button --
              if (_isDownloading)
                const SizedBox(width: AppSpacing.xl)
              else if (downloaded && updateAvailable)
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onUpdate,
                )
              else if (downloaded) ...[
                if (onSwap != null)
                  Builder(
                    builder: (btnContext) => IconButton(
                      icon: Icon(
                        Icons.swap_horiz,
                        color: AppColors.tileTextSecondary,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onSwap!(btnContext),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.tileTextFaint,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ]
              else ...[
                if (onSwap != null)
                  Builder(
                    builder: (btnContext) => IconButton(
                      icon: Icon(
                        Icons.swap_horiz,
                        color: onDownload != null
                            ? AppColors.tileTextSecondary
                            : AppColors.tileTextFaint,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDownload != null
                          ? () => onSwap!(btnContext)
                          : null,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    color: onDownload != null
                        ? AppColors.tileTextSecondary
                        : AppColors.tileTextFaint,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDownload,
                ),
              ],
            ],
          ),
          // Progress bar
          if (_isDownloading) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress! > 0 ? progress : null,
                backgroundColor: AppColors.tileText.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
