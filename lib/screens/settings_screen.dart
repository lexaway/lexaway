import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers.dart';
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
      backgroundColor: Colors.brown.shade900,
      body: Stack(
        children: [
          Opacity(
            opacity: 0.15,
            child: TiledBackground(
              texture: BackgroundTexture.chevron,
              color: Colors.brown.shade700,
              scale: 8,
              scrollDirection: const Offset(-1, 1),
              scrollSpeed: 12,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settings',
                        style: GoogleFonts.pixelifySans(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
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
        color: Colors.white70,
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
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.pixelifySans(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.amber.shade600,
                inactiveTrackColor: Colors.blueGrey.shade700,
                thumbColor: Colors.amber.shade400,
                overlayColor: Colors.amber.withValues(alpha: 0.2),
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
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.amber.shade400,
            activeTrackColor: Colors.amber.shade800,
            inactiveThumbColor: Colors.blueGrey.shade300,
            inactiveTrackColor: Colors.blueGrey.shade700,
          ),
        ],
      ),
    );
  }
}
