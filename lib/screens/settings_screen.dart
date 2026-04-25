import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_font.dart';
import '../data/app_urls.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/tiled_background.dart';

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

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textSecondary,
        title: Text(l10n.settings),
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.15,
            child: TiledBackground(
              texture: BackgroundTexture.chevron,
              color: AppColors.surfaceBright,
              scale: 8,
              scrollDirection: const Offset(-1, 1),
              scrollSpeed: 12,
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/ui/panel_metal_bg.png',
                      ),
                      centerSlice: Rect.fromLTRB(12, 12, 84, 84),
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
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
                        onChanged: (v) =>
                            ref.read(sfxVolumeProvider.notifier).set(v),
                        onChangeEnd: (_) =>
                            ref.read(sfxVolumeProvider.notifier).save(),
                      ),
                      _VolumeSlider(
                        label: l10n.settingsMusic,
                        value: bgmVol,
                        onChanged: (v) =>
                            ref.read(bgmVolumeProvider.notifier).set(v),
                        onChangeEnd: (_) =>
                            ref.read(bgmVolumeProvider.notifier).save(),
                      ),
                      _VolumeSlider(
                        label: l10n.voice,
                        value: ttsVol,
                        onChanged: (v) =>
                            ref.read(ttsVolumeProvider.notifier).set(v),
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
                      _SectionHeader(label: l10n.settingsDailyGoal),
                      const SizedBox(height: AppSpacing.sm),
                      const _DailyGoalSection(),
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
                          onTap: () =>
                              ref.read(fontProvider.notifier).set(font),
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
                        label: l10n.attributions,
                        onTap: () => context.push('/attributions'),
                      ),
                      _LinkRow(
                        label: l10n.privacyPolicy,
                        onTap: () {
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          launchUrl(
                            Uri.parse(privacyPolicyUrl(lang)),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 18,
      ),
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
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
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
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalSection extends ConsumerWidget {
  const _DailyGoalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyGoalProvider);
    final enabled = ref.watch(reminderEnabledProvider);
    final time = ref.watch(reminderTimeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoalTierGrid(
          selected: goal,
          onSelect: (v) => ref.read(dailyGoalProvider.notifier).set(v),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ToggleRow(
          label: l10n.settingsReminder,
          value: enabled,
          onChanged: (v) async {
            final result = await setReminderEnabled(ref, v);
            if (!result && v && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.settingsReminderPermissionDenied),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: _TimePickerRow(
              label: l10n.settingsReminderTime,
              value: time,
              onPick: (t) => ref.read(reminderTimeProvider.notifier).set(t),
            ),
          ),
      ],
    );
  }
}

class _GoalTierGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _GoalTierGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - AppSpacing.xs) / 2;
          return Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preset in dailyGoalPresets)
                SizedBox(
                  width: tileWidth,
                  child: _GoalTile(
                    timeLabel: l10n.goalTimeApprox(preset.minutes),
                    tierLabel: _tierLabel(l10n, preset.tier),
                    selected: preset.steps == selected,
                    onTap: () => onSelect(preset.steps),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _tierLabel(AppLocalizations l10n, GoalTier tier) {
    switch (tier) {
      case GoalTier.quick:
        return l10n.goalTierQuick;
      case GoalTier.short:
        return l10n.goalTierShort;
      case GoalTier.medium:
        return l10n.goalTierMedium;
      case GoalTier.long:
        return l10n.goalTierLong;
    }
  }
}

class _GoalTile extends StatelessWidget {
  final String timeLabel;
  final String tierLabel;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.timeLabel,
    required this.tierLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDark : AppColors.controlInactive,
          border: Border.all(
            color:
                selected ? AppColors.accentLight : AppColors.controlInactiveThumb,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeLabel,
              style: TextStyle(
                color:
                    selected ? AppColors.accentLight : AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tierLabel,
              style: TextStyle(
                color:
                    selected ? AppColors.accentLight : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;

  const _TimePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
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
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: value,
              );
              if (picked != null) onPick(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.controlInactive,
                border: Border.all(
                  color: AppColors.controlInactiveThumb,
                  width: 1,
                ),
              ),
              child: Text(
                value.format(context),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
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
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 18,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
