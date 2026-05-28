import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_font.dart';
import '../data/app_urls.dart';
import '../data/music_manager.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/endonyms.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final masterVol = ref.watch(masterVolumeProvider);
    final sfxVol = ref.watch(sfxVolumeProvider);
    final bgmVol = ref.watch(bgmVolumeProvider);
    final ttsVol = ref.watch(ttsVolumeProvider);
    final haptics = ref.watch(hapticsEnabledProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // panel_metal_bg.png is 96×96 with a 12px slice border on each
          // side. When the container shrinks below ~24px tall (mid sheet
          // dismiss), Flutter's centerSlice path asserts because the slice
          // corners no longer fit. Skip the decoration in that case.
          final canRenderPanel = constraints.maxHeight >= 32;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: canRenderPanel
                ? const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/panel_metal_bg.png'),
                      fit: BoxFit.fill,
                      centerSlice: Rect.fromLTRB(12, 12, 84, 84),
                      filterQuality: FilterQuality.none,
                    ),
                  )
                : null,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settings,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _SectionHeader(label: l10n.settingsSound),
                const SizedBox(height: AppSpacing.sm),
                _VolumeSlider(
                  label: l10n.settingsMaster,
                  value: masterVol,
                  onChanged: (v) =>
                      ref.read(masterVolumeProvider.notifier).set(v),
                  onChangeEnd: (_) =>
                      ref.read(masterVolumeProvider.notifier).save(),
                ),
                _VolumeSlider(
                  label: l10n.settingsSfx,
                  value: sfxVol,
                  onChanged: (v) => ref.read(sfxVolumeProvider.notifier).set(v),
                  onChangeEnd: (_) =>
                      ref.read(sfxVolumeProvider.notifier).save(),
                ),
                _VolumeSlider(
                  label: l10n.settingsMusic,
                  value: bgmVol,
                  onChanged: (v) => ref.read(bgmVolumeProvider.notifier).set(v),
                  onChangeEnd: (_) =>
                      ref.read(bgmVolumeProvider.notifier).save(),
                ),
                _VolumeSlider(
                  label: l10n.voice,
                  value: ttsVol,
                  onChanged: (v) => ref.read(ttsVolumeProvider.notifier).set(v),
                  onChangeEnd: (_) =>
                      ref.read(ttsVolumeProvider.notifier).save(),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsGameplay),
                const SizedBox(height: AppSpacing.sm),
                _ToggleRow(
                  label: l10n.settingsHaptics,
                  value: haptics,
                  onChanged: (v) =>
                      ref.read(hapticsEnabledProvider.notifier).set(v),
                ),
                _ToggleRow(
                  label: l10n.settingsAutoPlayVoice,
                  value: ref.watch(autoPlayTtsProvider),
                  onChanged: (v) =>
                      ref.read(autoPlayTtsProvider.notifier).set(v),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsNotifications),
                const SizedBox(height: AppSpacing.sm),
                const _NotificationsSection(),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsMusicPack),
                const SizedBox(height: AppSpacing.sm),
                const _MusicPackSection(),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsDifficulty),
                const SizedBox(height: AppSpacing.sm),
                for (final entry in {
                  'beginner': l10n.difficultyBeginner,
                  'intermediate': l10n.difficultyIntermediate,
                  'advanced': l10n.difficultyAdvanced,
                }.entries)
                  _RadioRow(
                    label: entry.value,
                    selected: ref.watch(difficultyProvider) == entry.key,
                    onTap: () =>
                        ref.read(difficultyProvider.notifier).set(entry.key),
                  ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsFont),
                const SizedBox(height: AppSpacing.sm),
                for (final font in AppFont.values)
                  _FontPickerRow(
                    font: font,
                    selected: ref.watch(fontProvider) == font,
                    onTap: () => ref.read(fontProvider.notifier).set(font),
                  ),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: l10n.settingsAbout),
                const SizedBox(height: AppSpacing.sm),
                _LinkRow(
                  label: 'Discord',
                  onTap: () => launchUrl(
                    Uri.parse(discordInvite),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _LinkRow(
                  label: 'Collection',
                  onTap: () => context.push('/collection'),
                ),
                _LinkRow(
                  label: l10n.attributions,
                  onTap: () => context.push('/attributions'),
                ),
                _LinkRow(
                  label: l10n.privacyPolicy,
                  onTap: () async {
                    final lang = Localizations.localeOf(context).languageCode;
                    final uri = Uri.parse(privacyPolicyUrl(lang));
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final ok = await launchUrl(
                        uri,
                        mode: LaunchMode.inAppBrowserView,
                      );
                      if (!ok) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Could not open $uri')),
                        );
                      }
                    } catch (_) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Could not open $uri')),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 18),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.controlInactive,
                thumbColor: AppColors.accentLight,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentLight,
            activeTrackColor: AppColors.accentDark,
            inactiveThumbColor: AppColors.controlInactiveThumb,
            inactiveTrackColor: AppColors.controlInactive,
          ),
        ],
      ),
    );
  }
}

class _FontPickerRow extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final VoidCallback onTap;

  const _FontPickerRow({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                font.displayName,
                style: TextStyle(
                  fontFamily: font.family,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicPackSection extends ConsumerWidget {
  const _MusicPackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(musicCatalogProvider);
    final installedAsync = ref.watch(installedMusicProvider);
    final installed = installedAsync.valueOrNull ?? const <String>{};

    if (catalog.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pack in catalog)
          _MusicPackRow(
            pack: pack,
            downloaded: installed.contains(pack.id),
            progress: ref.watch(musicDownloadProgressProvider(pack.id)),
            extractingLabel: l10n.extracting,
            optionalLabel: l10n.optional,
            trackCountLabel: l10n.musicTrackCount(pack.tracks.length),
            onDownload: () =>
                ref.read(installedMusicProvider.notifier).download(pack.id),
            onDelete: () =>
                ref.read(installedMusicProvider.notifier).delete(pack.id),
          ),
      ],
    );
  }
}

class _MusicPackRow extends StatelessWidget {
  final MusicPackInfo pack;
  final bool downloaded;
  final double? progress;
  final String extractingLabel;
  final String optionalLabel;
  final String trackCountLabel;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _MusicPackRow({
    required this.pack,
    required this.downloaded,
    required this.progress,
    required this.extractingLabel,
    required this.optionalLabel,
    required this.trackCountLabel,
    required this.onDownload,
    required this.onDelete,
  });

  bool get _isDownloading => progress != null;

  @override
  Widget build(BuildContext context) {
    final isExtracting = _isDownloading && progress! < 0;
    final trackCount = pack.tracks.length;
    // Empty `tracks` only happens with the bundled baseline before the
    // remote manifest has loaded. Downloading then would leave the catalog
    // unable to resolve any tracks, so block the action until manifest
    // arrives — UI still shows the tile so users know the pack exists.
    final manifestLoaded = trackCount > 0;
    final subtitle = isExtracting
        ? extractingLabel
        : downloaded
        ? (trackCount > 0 ? trackCountLabel : null)
        : optionalLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: _isDownloading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress! > 0 ? progress : null,
                            color: AppColors.accent,
                            backgroundColor: AppColors.textPrimary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        )
                      : downloaded
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 22,
                        )
                      : const Icon(
                          Icons.music_note,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pack.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '~${pack.approximateSizeMB} MB',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isDownloading)
                const SizedBox(width: AppSpacing.xl)
              else if (downloaded)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    color: manifestLoaded
                        ? AppColors.accent
                        : AppColors.textFaint,
                    size: 24,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: manifestLoaded ? onDownload : null,
                ),
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress! > 0 ? progress : null,
                backgroundColor: AppColors.textPrimary.withValues(alpha: 0.12),
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

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: AppColors.accent, fontSize: 16),
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(notifSettingsProvider);
    final installed = ref.watch(installedL2sProvider);
    final disabled = !settings.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ToggleRow(
          label: l10n.notifMaster,
          value: settings.enabled,
          onChanged: (v) =>
              ref.read(notifSettingsProvider.notifier).setEnabled(v),
        ),
        Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerDaySlider(
                  value: settings.perDay,
                  onChanged: (v) =>
                      ref.read(notifSettingsProvider.notifier).setPerDay(v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    l10n.notifActiveWindow,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                _TimeRow(
                  label: l10n.notifStartTime,
                  hour: settings.startHour,
                  onPick: (h) => ref.read(notifSettingsProvider.notifier)
                      .setWindow(startHour: h, endHour: settings.endHour),
                ),
                _TimeRow(
                  label: l10n.notifEndTime,
                  hour: settings.endHour,
                  onPick: (h) => ref.read(notifSettingsProvider.notifier)
                      .setWindow(startHour: settings.startHour, endHour: h),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    l10n.notifLanguages,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (installed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                      l10n.notifNoPacks,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      for (final iso3 in installed)
                        FilterChip(
                          label: Text(endonymFor(iso3)),
                          selected: settings.langs.contains(iso3),
                          onSelected: (on) => ref
                              .read(notifSettingsProvider.notifier)
                              .toggleLang(iso3, on),
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.accentDark,
                          checkmarkColor: AppColors.textPrimary,
                          labelStyle: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          side: BorderSide(color: AppColors.surfaceBorder),
                        ),
                    ],
                  ),
                  if (settings.langs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l10n.notifPickAtLeastOne,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                const _NotifPreviewCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-day slider. Local state during drag so we don't fire a full reschedule
/// on every frame — the actual `setPerDay` only happens on `onChangeEnd`,
/// matching the `_VolumeSlider` "tick during drag, save on release" pattern.
class _PerDaySlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PerDaySlider({required this.value, required this.onChanged});

  @override
  State<_PerDaySlider> createState() => _PerDaySliderState();
}

class _PerDaySliderState extends State<_PerDaySlider> {
  late double _drag = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _PerDaySlider old) {
    super.didUpdateWidget(old);
    // Pick up external changes (e.g. settings restored from Hive) when we're
    // not actively dragging.
    if (old.value != widget.value) _drag = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = _drag.round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              l10n.notifPerDay,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.controlInactive,
                thumbColor: AppColors.accentLight,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _drag,
                min: 1,
                max: 8,
                divisions: 7,
                label: '$shown',
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) => widget.onChanged(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$shown',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onPick;
  const _TimeRow({
    required this.label,
    required this.hour,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final tod = TimeOfDay(hour: hour, minute: 0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: tod,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppColors.accent,
                onPrimary: AppColors.textPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked.hour);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Text(
                tod.format(context),
                style: TextStyle(color: AppColors.accent, fontSize: 16),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifPreviewCard extends ConsumerWidget {
  const _NotifPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(notifPreviewProvider);
    final preview = async.valueOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.notifPreview,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.invalidate(notifPreviewProvider),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.surfaceBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: preview == null
                  ? Text(
                      l10n.notifPreviewEmpty,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview.body,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
