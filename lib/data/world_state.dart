/// Immutable snapshot of persistable world state.
///
/// Produced by [LexawayGame] when it's time to persist, and consumed when the
/// game boots to restore the player's last position.
class WorldState {
  final int seed;
  final int extensions;
  final double scrollOffset;
  final List<int> collectedCoins;
  final List<int> usedClawMachines;

  const WorldState({
    required this.seed,
    required this.extensions,
    required this.scrollOffset,
    required this.collectedCoins,
    this.usedClawMachines = const [],
  });

  Map<String, dynamic> toMap() => {
        'seed': seed,
        'extensions': extensions,
        'scroll_offset': scrollOffset,
        'collected_coins': collectedCoins,
        'used_claw_machines': usedClawMachines,
      };

  /// Parse a raw Hive map. Returns null if [raw] is null or any field has an
  /// unexpected type; corrupt data is treated as "no save" rather than
  /// crashing boot. Missing optional fields fall back to defaults.
  static WorldState? fromMap(Map? raw) {
    if (raw == null) return null;
    final seed = raw['seed'];
    if (seed is! int) return null;
    final extensions = raw['extensions'];
    if (extensions != null && extensions is! int) return null;
    final scrollOffset = raw['scroll_offset'];
    if (scrollOffset != null && scrollOffset is! num) return null;
    final collectedCoins = raw['collected_coins'];
    if (collectedCoins != null && collectedCoins is! List) return null;
    final usedClawMachines = raw['used_claw_machines'];
    if (usedClawMachines != null && usedClawMachines is! List) return null;
    return WorldState(
      seed: seed,
      extensions: (extensions as int?) ?? 0,
      scrollOffset: (scrollOffset as num?)?.toDouble() ?? 0,
      collectedCoins:
          (collectedCoins as List?)?.cast<int>() ?? const [],
      usedClawMachines:
          (usedClawMachines as List?)?.cast<int>() ?? const [],
    );
  }
}
