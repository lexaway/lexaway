import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/hive_keys.dart';
import 'bootstrap.dart';

/// Player-owned collectible ids, keyed by `<kind>:<id>` (e.g. `flag:fr`).
/// Backed by Hive — persisted across sessions. Membership-only today; if
/// duplicate-tracking ever becomes a feature we can swap this to a map.
final collectionProvider = NotifierProvider<CollectionNotifier, Set<String>>(
  CollectionNotifier.new,
);

class CollectionNotifier extends Notifier<Set<String>> {
  Box get _box => ref.read(hiveBoxProvider);

  @override
  Set<String> build() {
    final raw = _box.get(HiveKeys.collectibles, defaultValue: <String>[]);
    if (raw is List) return raw.cast<String>().toSet();
    return <String>{};
  }

  /// Returns true if the id was newly added; false if it was already owned.
  /// The boolean drives the result dialog's "New!" / "Already owned" copy.
  bool add(String id) {
    if (state.contains(id)) return false;
    final next = {...state, id};
    state = next;
    _box.put(HiveKeys.collectibles, next.toList());
    return true;
  }

  bool has(String id) => state.contains(id);
}
