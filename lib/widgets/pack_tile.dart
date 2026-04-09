import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/pack_manager.dart';
import '../data/tts_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'content_row.dart';

class PackTile extends StatelessWidget {
  final PackInfo pack;
  final LocalPack? local;
  final PackUpdateStatus packStatus;
  final double? packProgress;
  final double? voiceProgress;
  final List<TtsModelInfo> voiceModels;
  final String? downloadedModelId;
  final bool hasCharacter;
  final VoidCallback onDownload;
  final VoidCallback onUpdate;
  final void Function(String modelId) onDownloadVoice;
  final VoidCallback onDelete;
  final VoidCallback onDeleteVoice;
  final VoidCallback onSelect;

  const PackTile({
    super.key,
    required this.pack,
    required this.local,
    required this.packStatus,
    required this.packProgress,
    required this.voiceProgress,
    required this.voiceModels,
    required this.downloadedModelId,
    required this.hasCharacter,
    required this.onDownload,
    required this.onUpdate,
    required this.onDownloadVoice,
    required this.onDelete,
    required this.onDeleteVoice,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _hasVoiceSupport => voiceModels.isNotEmpty;
  bool get _voiceDownloaded => downloadedModelId != null;

  TtsModelInfo? get _activeVoice {
    if (downloadedModelId == null) return null;
    for (final m in voiceModels) {
      if (m.modelId == downloadedModelId) return m;
    }
    return null;
  }

  void _showVoicePicker(BuildContext buttonContext) {
    final RenderBox button = buttonContext.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: buttonContext,
      position: position,
      color: AppColors.surface,
      items: [
        for (final model in voiceModels)
          PopupMenuItem<String>(
            value: model.modelId,
            enabled: model.modelId != downloadedModelId,
            child: Text(
              '${model.displayName}  ~${model.approximateSizeMB} MB',
              style: TextStyle(
                color: model.modelId == downloadedModelId
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
      ],
    ).then((modelId) {
      if (modelId != null) onDownloadVoice(modelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            _isDownloaded
                ? 'assets/images/ui/tile_pack_green_bg.png'
                : 'assets/images/ui/tile_pack_bg.png',
          ),
          centerSlice: _isDownloaded
              ? const Rect.fromLTRB(24, 24, 72, 72)
              : const Rect.fromLTRB(15, 15, 81, 78),
          filterQuality: FilterQuality.none,
        ),
      ),
      child: Column(
        children: [
          // -- Header row: badge + language name --
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tileText.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    pack.lang.toUpperCase(),
                    style: GoogleFonts.pixelifySans(
                      color: AppColors.tileTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    pack.name,
                    style: GoogleFonts.pixelifySans(
                      color: AppColors.tileText,
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
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: AppColors.tileText.withValues(alpha: 0.08),
          ),
          ContentRow(
            icon: Icons.text_snippet_outlined,
            label: l10n.sentences,
            sizeText: _isDownloaded ? _formatMB(local!.sizeBytes) : null,
            downloaded: _isDownloaded,
            updateAvailable: packStatus == PackUpdateStatus.updateAvailable,
            progress: packProgress,
            onDownload: onDownload,
            onUpdate: onUpdate,
            onDelete: onDelete,
          ),
          // -- Voice row (optional, only if TTS is supported) --
          if (_hasVoiceSupport) ...[
            Divider(
              height: 1,
              thickness: 1,
              indent: 14,
              endIndent: 14,
              color: AppColors.tileText.withValues(alpha: 0.08),
            ),
            ContentRow(
              icon: Icons.volume_up_rounded,
              label: (_activeVoice ?? voiceModels.first).displayName,
              subtitle: voiceProgress != null && voiceProgress! < 0
                  ? l10n.extracting
                  : _voiceDownloaded ? null : l10n.optional,
              sizeText: '~${(_activeVoice ?? voiceModels.first).approximateSizeMB} MB',
              downloaded: _voiceDownloaded,
              progress: voiceProgress,
              onDownload: _isDownloaded
                  ? () => onDownloadVoice(voiceModels.first.modelId)
                  : null,
              onDelete: onDeleteVoice,
              onSwap: _isDownloaded && voiceModels.length > 1 && voiceProgress == null
                  ? (btnContext) => _showVoicePicker(btnContext)
                  : null,
            ),
          ],
          // -- Action button --
          Divider(
            height: 1,
            thickness: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: AppColors.tileText.withValues(alpha: 0.08),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDownloaded && packStatus != PackUpdateStatus.appUpdateRequired
                  ? onSelect
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  packStatus == PackUpdateStatus.appUpdateRequired
                      ? l10n.updateApp
                      : hasCharacter
                          ? l10n.continueLabel
                          : l10n.start,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pixelifySans(
                    color: packStatus == PackUpdateStatus.appUpdateRequired
                        ? AppColors.accent
                        : _isDownloaded
                            ? AppColors.success
                            : AppColors.tileTextFaint,
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
