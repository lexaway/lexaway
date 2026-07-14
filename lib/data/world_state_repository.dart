import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import 'hive_keys.dart';
import 'world_state.dart';

/// Sole read/write path for persistent world state. One instance per target
/// language (each pack has its own dino world). Game code must go through here,
/// never [HiveKeys.world] directly.
class WorldStateRepository {
  final Box _box;
  final String _lang;

  WorldStateRepository(this._box, this._lang);

  String get _key => HiveKeys.world(_lang);

  /// Returns saved world state, or null if absent/corrupt. Corruption logs and
  /// falls back to a fresh start (loud loss beats a boot crash).
  WorldState? load() {
    final Object? raw;
    try {
      raw = _box.get(_key);
    } catch (e) {
      debugPrint('world_state_repository: load failed ($e)');
      return null;
    }
    if (raw == null) return null;
    if (raw is! Map) {
      debugPrint('world_state_repository: stored value is ${raw.runtimeType}, '
          'expected Map — discarding');
      return null;
    }
    final state = WorldState.fromMap(raw);
    if (state == null) {
      debugPrint('world_state_repository: stored map failed schema check — '
          'discarding');
    }
    return state;
  }

  void save(WorldState state) {
    _box.put(_key, state.toMap());
  }
}
