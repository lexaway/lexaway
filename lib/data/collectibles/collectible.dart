/// Shared abstraction for collectible prizes. Only [FlagCollectible] exists
/// today; the cabinet/persistence/collection code talks to this so new kinds
/// slot in without rewiring.
abstract class Collectible {
  /// Globally-unique id, namespaced by kind (e.g. `flag:fr`). Persistence key
  /// and identity through game events.
  String get id;

  /// Category id (e.g. `flags`). Cabinets roll a loadout from one category.
  String get categoryId;

  /// Player-facing display name (English for now).
  String get displayName;

  /// Bundled sprite asset path.
  String get spriteAsset;
}

class FlagCollectible implements Collectible {
  /// ISO 3166-1 alpha-2 country code (lowercase, e.g. `fr`).
  final String iso2;
  @override
  final String displayName;

  const FlagCollectible({required this.iso2, required this.displayName});

  @override
  String get id => 'flag:$iso2';
  @override
  String get categoryId => 'flags';
  @override
  String get spriteAsset => 'assets/flags/$iso2.png';
}

class CollectibleCategory {
  final String id;
  final String displayName;
  final List<Collectible> items;

  const CollectibleCategory({
    required this.id,
    required this.displayName,
    required this.items,
  });
}
