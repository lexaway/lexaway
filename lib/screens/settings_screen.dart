import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../widgets/tiled_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterVol = ref.watch(masterVolumeProvider);
    final sfxVol = ref.watch(sfxVolumeProvider);
    final ttsVol = ref.watch(ttsVolumeProvider);
    final haptics = ref.watch(hapticsEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textSecondary,
        title: Text(AppLocalizations.of(context)!.settings),
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
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
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
                      _SectionHeader(label: 'Sound'),
                      const SizedBox(height: 8),
                      _VolumeSlider(
                        label: 'Master',
                        value: masterVol,
                        onChanged: (v) =>
                            ref.read(masterVolumeProvider.notifier).set(v),
                        onChangeEnd: (_) =>
                            ref.read(masterVolumeProvider.notifier).save(),
                      ),
                      _VolumeSlider(
                        label: 'SFX',
                        value: sfxVol,
                        onChanged: (v) =>
                            ref.read(sfxVolumeProvider.notifier).set(v),
                        onChangeEnd: (_) =>
                            ref.read(sfxVolumeProvider.notifier).save(),
                      ),
                      _VolumeSlider(
                        label: 'Voice',
                        value: ttsVol,
                        onChanged: (v) =>
                            ref.read(ttsVolumeProvider.notifier).set(v),
                        onChangeEnd: (_) =>
                            ref.read(ttsVolumeProvider.notifier).save(),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(label: 'Gameplay'),
                      const SizedBox(height: 8),
                      _ToggleRow(
                        label: 'Haptics',
                        value: haptics,
                        onChanged: (v) =>
                            ref.read(hapticsEnabledProvider.notifier).set(v),
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
      style: GoogleFonts.pixelifySans(
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                style: GoogleFonts.pixelifySans(
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.pixelifySans(
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
