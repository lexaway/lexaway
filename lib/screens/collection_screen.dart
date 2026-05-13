import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collectibles/collectible.dart';
import '../data/collectibles/registry.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Grid view of every flag in the `flags` category. Owned flags render in
/// full color with their name; unowned slots show a silhouetted flag and a
/// `???` placeholder so the player has a sense of how much there is to
/// collect without spoiling specific entries.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category =
        CollectibleRegistry.instance.categoryById('flags');
    final owned = ref.watch(collectionProvider);

    final items = category?.items ?? const <Collectible>[];
    final ownedCount = items.where((c) => owned.contains(c.id)).length;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Collection'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '$ownedCount / ${items.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final c = items[i];
            final isOwned = owned.contains(c.id);
            return _CollectionTile(collectible: c, owned: isOwned);
          },
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final Collectible collectible;
  final bool owned;
  const _CollectionTile({required this.collectible, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: owned ? AppColors.accentDark : AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: _FlagImage(asset: collectible.spriteAsset, owned: owned),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            owned ? collectible.displayName : '???',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: owned ? AppColors.textPrimary : AppColors.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the flag image at full color when [owned], or as a dark
/// silhouette (alpha preserved, rgb crushed to black) when unowned.
class _FlagImage extends StatelessWidget {
  final String asset;
  final bool owned;
  const _FlagImage({required this.asset, required this.owned});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
    );
    if (owned) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0, 0, 0, 0, 30,
        0, 0, 0, 0, 30,
        0, 0, 0, 0, 30,
        0, 0, 0, 0.7, 0,
      ]),
      child: image,
    );
  }
}
