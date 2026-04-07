import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/pack_manager.dart';
import '../data/tts_manager.dart';
import '../theme/app_colors.dart';
import 'content_row.dart';

class PackTile extends StatelessWidget {
  final PackInfo pack;
  final LocalPack? local;
  final double? packProgress;
  final double? voiceProgress;
  final bool voiceDownloaded;
  final bool includeVoice;
  final ValueChanged<bool> onToggleVoice;
  final VoidCallback onDownload;
  final VoidCallback onDownloadVoice;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const PackTile({
    super.key,
    required this.pack,
    required this.local,
    required this.packProgress,
    required this.voiceProgress,
    required this.voiceDownloaded,
    required this.includeVoice,
    required this.onToggleVoice,
    required this.onDownload,
    required this.onDownloadVoice,
    required this.onDelete,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _hasVoiceSupport => TtsManager.isSupported(pack.lang);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDownloaded
              ? AppColors.successDark.withValues(alpha: 0.5)
              : AppColors.surfaceBorder.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // -- Sentences row (primary, always present) --
          ContentRow(
            icon: Icons.text_snippet_outlined,
            label: AppLocalizations.of(context)!.sentences,
            sizeText: _isDownloaded ? _formatMB(local!.sizeBytes) : null,
            downloaded: _isDownloaded,
            progress: packProgress,
            onTap: _isDownloaded ? onSelect : onDownload,
            trailing: _buildSentencesTrailing(),
            // Top row gets the language badge
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceBright,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                pack.lang.toUpperCase(),
                style: GoogleFonts.pixelifySans(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: pack.name,
          ),
          // -- Voice row (optional, only if TTS is supported) --
          if (_hasVoiceSupport) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.surfaceBright.withValues(alpha: 0.6),
            ),
            ContentRow(
              icon: Icons.volume_up_rounded,
              label: AppLocalizations.of(context)!.voice,
              sizeText:
                  '~${ttsModelRegistry[pack.lang]!.approximateSizeMB} MB',
              downloaded: voiceDownloaded,
              progress: voiceProgress,
              onTap: !_isDownloaded && !voiceDownloaded
                  ? () => onToggleVoice(!includeVoice)
                  : null,
              trailing: _buildVoiceTrailing(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentencesTrailing() {
    if (packProgress != null) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textTertiary),
      );
    }
    if (_isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_rounded, color: AppColors.textSecondary, size: 24),
      visualDensity: VisualDensity.compact,
      onPressed: onDownload,
    );
  }

  Widget _buildVoiceTrailing() {
    if (voiceProgress != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: voiceProgress,
            color: AppColors.textTertiary,
            backgroundColor: AppColors.surfaceBright,
          ),
        ),
      );
    }
    if (voiceDownloaded) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.check_circle, color: AppColors.success, size: 20),
      );
    }
    // Sentences installed but voice isn't — show download button
    if (_isDownloaded) {
      return IconButton(
        icon: Icon(
          Icons.download_rounded,
          color: AppColors.textPrimary.withValues(alpha: 0.5),
          size: 22,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: onDownloadVoice,
      );
    }
    // Nothing installed yet — toggle inclusion for bundled download
    return GestureDetector(
      onTap: () => onToggleVoice(!includeVoice),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: includeVoice
                  ? AppColors.accent
                  : AppColors.textPrimary.withValues(alpha: 0.25),
              width: 2,
            ),
            color: includeVoice ? AppColors.accent : Colors.transparent,
          ),
          child: includeVoice
              ? const Icon(Icons.check, size: 14, color: AppColors.textPrimary)
              : null,
        ),
      ),
    );
  }

  String _formatMB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
