import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/tiled_background.dart';

class AttributionsScreen extends StatelessWidget {
  const AttributionsScreen({super.key});

  static const _attributions = [
    _Attribution('Sentence Data (CC BY 2.0 FR)', 'Tatoeba contributors — sentences adapted for fill-in-the-blank', 'https://tatoeba.org'),
    _Attribution('Dino Characters', 'Arks', 'https://arks.itch.io/dino-characters'),
    _Attribution('Dino Family', 'ScissorMarks & Demching', 'https://demching.itch.io/dino-family'),
    _Attribution('400 Sounds Pack', 'Ci', 'https://ci.itch.io/400-sounds-pack'),
    _Attribution('Footsteps', 'Nox_Sound', 'https://freesound.org/people/Nox_Sound/'),
    _Attribution("Towball's Crossing (CC BY 4.0)", 'Towball', 'https://towball.itch.io/towballs-crossing'),
    _Attribution('Seasonal Tilesets', 'GrafxKid', 'https://grafxkid.itch.io/seasonal-tilesets'),
    _Attribution('UI Pack Pixel Adventure', 'Kenney', 'https://kenney.nl/assets/ui-pack-pixel-adventure'),
    _Attribution('Gems & Coins', 'La Red Games', 'https://laredgames.itch.io/gems-coins-free'),
    _Attribution('Backgrounds & Textures', 'Morain', 'https://morain.itch.io/backgrounds-and-textures'),
    _Attribution('Fantasy Icons Pack', 'Matt Firth (shikashipx) & game-icons.net', 'https://shikashipx.itch.io/shikashis-fantasy-icons-pack'),
    _Attribution('Assorted Icons', 'Quintino Pixels', 'https://quintino-pixels.itch.io/assorted-icons'),
    _Attribution('Pixelify Sans (SIL OFL)', 'Stefie Justprince', 'https://fonts.google.com/specimen/Pixelify+Sans'),
    _Attribution('Atkinson Hyperlegible (SIL OFL)', 'Braille Institute', 'https://brailleinstitute.org/freefont'),
    _Attribution('Nunito (SIL OFL)', 'Vernon Adams et al.', 'https://fonts.google.com/specimen/Nunito'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textSecondary,
        title: Text(AppLocalizations.of(context)!.attributions),
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
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _attributions.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                      height: AppSpacing.md,
                    ),
                    itemBuilder: (context, index) {
                      final attr = _attributions[index];
                      return _AttributionTile(attribution: attr);
                    },
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

class _Attribution {
  final String asset;
  final String author;
  final String url;

  const _Attribution(this.asset, this.author, this.url);
}

class _AttributionTile extends StatelessWidget {
  final _Attribution attribution;

  const _AttributionTile({required this.attribution});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(attribution.url),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attribution.asset,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attribution.author,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
