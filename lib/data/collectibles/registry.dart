import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'collectible.dart';
import 'flag_names.dart';

/// Process-wide collectible registry, built once on first access (flag data is
/// compiled in) and cached. Also caches decoded flag `ui.Image`s so the cabinet
/// and result dialog share bitmaps.
class CollectibleRegistry {
  CollectibleRegistry._() {
    _init();
  }

  static final CollectibleRegistry instance = CollectibleRegistry._();

  late final Map<String, CollectibleCategory> _categories;
  late final Map<String, Collectible> _byId;

  // Keyed by asset path so every collectible kind shares the same cache.
  final Map<String, ui.Image> _spriteCache = {};
  final Map<String, Future<ui.Image>> _spriteInflight = {};

  void _init() {
    // Only expose flags with an English display name — the asset folder has
    // the full ISO 3166 set, but unnamed ones would render as raw codes
    // (`XK`, `BQ`). Add a name in `flag_names.dart` to unlock a flag.
    final flagItems = <Collectible>[
      for (final entry in flagDisplayNames.entries)
        FlagCollectible(iso2: entry.key, displayName: entry.value),
    ];
    final flagsCategory = CollectibleCategory(
      id: 'flags',
      displayName: 'Flags',
      items: flagItems,
    );
    _categories = {flagsCategory.id: flagsCategory};
    _byId = {
      for (final c in flagItems) c.id: c,
    };
  }

  CollectibleCategory? categoryById(String id) => _categories[id];

  Collectible? collectibleById(String id) => _byId[id];

  /// Pick [count] random collectibles from [categoryId]. Duplicates allowed.
  /// Empty list if the category is unknown.
  List<Collectible> randomFromCategory(
    String categoryId,
    int count, {
    math.Random? rng,
  }) {
    final cat = _categories[categoryId];
    if (cat == null || cat.items.isEmpty) return const [];
    final r = rng ?? math.Random();
    return List.generate(
      count,
      (_) => cat.items[r.nextInt(cat.items.length)],
    );
  }

  /// Load and cache a sprite by asset path. Idempotent per path.
  Future<ui.Image> loadSprite(String assetPath) {
    final cached = _spriteCache[assetPath];
    if (cached != null) return Future.value(cached);
    final inflight = _spriteInflight[assetPath];
    if (inflight != null) return inflight;
    final fut = () async {
      final bytes = await rootBundle.load(assetPath);
      final codec =
          await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _spriteCache[assetPath] = frame.image;
      _spriteInflight.remove(assetPath);
      return frame.image;
    }();
    _spriteInflight[assetPath] = fut;
    return fut;
  }

  /// Synchronously fetch a loaded sprite, or null if not yet loaded —
  /// `paint`/`render`-loop callers should preload first.
  ui.Image? cachedSprite(String assetPath) => _spriteCache[assetPath];
}
