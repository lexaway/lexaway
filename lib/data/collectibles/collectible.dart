/// Shared spine for prizes the player can collect from cabinets, chests,
/// quests, etc. Today the only [Collectible] kind is [FlagCollectible],
/// but the rest of the system (cabinet loadout, inventory persistence,
/// collection screen) talks to this abstraction so new kinds slot in
/// without rewiring.
abstract class Collectible {
  /// Globally-unique id, namespaced by kind (e.g. `flag:fr`). Used as the
  /// persistence key and the identity carried through game events.
  String get id;

  /// Category id this collectible belongs to (e.g. `flags`). The cabinet
  /// rolls its loadout from a single category at spawn time.
  String get categoryId;

  /// Player-facing display name (English for now — localization is a
  /// follow-up).
  String get displayName;

  /// Bundled asset path for the sprite, used by in-game rendering and the
  /// collection screen.
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
