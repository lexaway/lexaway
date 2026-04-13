import 'package:hive_ce/hive_ce.dart';

import 'hive_keys.dart';

/// Current Hive box schema version. Bump when the shape of stored data changes
/// and add a migration case in [migrateHive].
const hiveSchemaVersion = 1;

void migrateHive(Box box) {
  final old = box.get(HiveKeys.hiveSchemaVersion, defaultValue: 0) as int;
  if (old >= hiveSchemaVersion) return;

  // Future migrations go here.

  box.put(HiveKeys.hiveSchemaVersion, hiveSchemaVersion);
}
