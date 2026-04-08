import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const ContentRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.sizeText,
    required this.downloaded,
    required this.progress,
    this.onDownload,
    this.onDelete,
  });

  bool get _isDownloading => progress != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            color: AppColors.textTertiary,
                            backgroundColor: AppColors.surfaceBright,
                          ),
                        )
                      : downloaded
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 20,
                            )
                          : Icon(
                              icon,
                              color: AppColors.textFaint,
                              size: 20,
                            ),
                ),
              ),
              const SizedBox(width: 14),
              // -- Label + size --
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textPrimary.withValues(alpha: 0.25),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // -- Right: action button --
              if (_isDownloading)
                const SizedBox(width: 28)
              else if (downloaded)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    color: onDownload != null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary.withValues(alpha: 0.15),
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDownload,
                ),
            ],
          ),
          // Progress bar
          if (_isDownloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress! > 0 ? progress : null,
                backgroundColor: AppColors.surfaceBright,
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
