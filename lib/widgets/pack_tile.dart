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
  final bool hasCharacter;
  final VoidCallback onDownload;
  final VoidCallback onDownloadVoice;
  final VoidCallback onDelete;
  final VoidCallback onDeleteVoice;
  final VoidCallback onSelect;

  const PackTile({
    super.key,
    required this.pack,
    required this.local,
    required this.packProgress,
    required this.voiceProgress,
    required this.voiceDownloaded,
    required this.hasCharacter,
    required this.onDownload,
    required this.onDownloadVoice,
    required this.onDelete,
    required this.onDeleteVoice,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _hasVoiceSupport => TtsManager.isSupported(pack.lang);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            _isDownloaded
                ? 'assets/images/ui/panel_metal_green_bg.png'
                : 'assets/images/ui/panel_metal_bg.png',
          ),
          centerSlice: _isDownloaded
              ? const Rect.fromLTRB(18, 18, 78, 78)
              : const Rect.fromLTRB(12, 12, 84, 84),
          filterQuality: FilterQuality.none,
        ),
      ),
      child: Column(
        children: [
          // -- Header row: badge + language name --
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    pack.name,
                    style: GoogleFonts.pixelifySans(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // -- Sentences row --
          Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
          ContentRow(
            icon: Icons.text_snippet_outlined,
            label: l10n.sentences,
            sizeText: _isDownloaded ? _formatMB(local!.sizeBytes) : null,
            downloaded: _isDownloaded,
            progress: packProgress,
            onDownload: onDownload,
            onDelete: onDelete,
          ),
          // -- Voice row (optional, only if TTS is supported) --
          if (_hasVoiceSupport) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
            ContentRow(
              icon: Icons.volume_up_rounded,
              label: l10n.voice,
              subtitle: l10n.optional,
              sizeText:
                  '~${ttsModelRegistry[pack.lang]!.approximateSizeMB} MB',
              downloaded: voiceDownloaded,
              progress: voiceProgress,
              onDownload: _isDownloaded ? onDownloadVoice : null,
              onDelete: onDeleteVoice,
            ),
          ],
          // -- Action button --
          Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.textPrimary.withValues(alpha: 0.08),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDownloaded ? onSelect : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  hasCharacter ? l10n.continueLabel : l10n.start,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pixelifySans(
                    color: _isDownloaded
                        ? AppColors.success
                        : AppColors.textFaint,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
