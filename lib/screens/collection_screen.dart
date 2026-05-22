import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collectibles/collectible.dart';
import '../data/collectibles/registry.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/tiled_background.dart';

/// Grid view of every flag in the `flags` category. Owned flags sit inside
/// a gilded frame; unowned slots show the grey frame with no flag, so the
/// player has a sense of how much there is to collect without spoiling
/// specific entries.
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
      backgroundColor: const Color(0xFF2E323A),
      extendBodyBehindAppBar: true,
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
      body: Stack(
        children: [
          RepaintBoundary(
            child: TiledBackground(
              texture: BackgroundTexture.stone,
              color: AppColors.surfaceBright.withValues(alpha: 0.15),
              scale: 8,
              scrollDirection: const Offset(-1, 1),
              scrollSpeed: 12,
            ),
          ),
          GridView.builder(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
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
        ],
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: _FramedSlot(
              frameIndex: owned ? _ownedFrameIndex : _unownedFrameIndex,
              child: owned ? _OwnedFlag(asset: collectible.spriteAsset) : null,
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
    );
  }
}

const int _ownedFrameIndex = 0; // yellow / gold
const int _unownedFrameIndex = 3; // grey

// Frame is 32x32 at source. We size the flag + 1px outline as a fraction of
// that so it scales pixel-cleanly inside the slot regardless of display size.
// Source-pixel intent: 18x12 flag (1.2x of 15x10) with a 1px outline → 20x14.
const double _frameSize = 32;
const double _outlinedW = 20;
const double _outlinedH = 14;
const double _flagW = 18;
const double _flagH = 12;
const Color _flagOutlineColor = Color(0xFF131549);

class _OwnedFlag extends StatelessWidget {
  final String asset;
  const _OwnedFlag({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: _outlinedW / _frameSize,
        heightFactor: _outlinedH / _frameSize,
        child: ColoredBox(
          color: _flagOutlineColor,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: _flagW / _outlinedW,
              heightFactor: _flagH / _outlinedH,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square slot painted from the 4-frame dragon GUI sheet. [frameIndex] picks
/// which frame: 0=gold, 1=green, 2=orange, 3=grey.
class _FramedSlot extends StatefulWidget {
  final int frameIndex;
  final Widget? child;
  const _FramedSlot({required this.frameIndex, this.child});

  @override
  State<_FramedSlot> createState() => _FramedSlotState();
}

class _FramedSlotState extends State<_FramedSlot> {
  ui.Image? _sheet;

  @override
  void initState() {
    super.initState();
    _FrameSheet.ensureLoaded().then((img) {
      if (mounted) setState(() => _sheet = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_sheet != null)
            CustomPaint(
              painter: _FramePainter(
                sheet: _sheet!,
                frameIndex: widget.frameIndex,
              ),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final ui.Image sheet;
  final int frameIndex;

  _FramePainter({required this.sheet, required this.frameIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      frameIndex * _frameSize,
      0,
      _frameSize,
      _frameSize,
    );
    final dst = Offset.zero & size;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.drawImageRect(sheet, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.sheet != sheet || old.frameIndex != frameIndex;
}

class _FrameSheet {
  static const _assetPath =
      'assets/tinyRPG_dragonRegaliaGUI_v1_0/20240713dragonFilledFrame-Sheet.png';

  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  static Future<ui.Image> ensureLoaded() {
    final cached = _image;
    if (cached != null) return Future.value(cached);
    return _pending ??= _load();
  }

  static Future<ui.Image> _load() async {
    final data = await rootBundle.load(_assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _image = frame.image;
    return frame.image;
  }
}
