import 'package:flame/components.dart';

/// Mixin for Flame components that persist state across app restarts.
///
/// Implement [saveKey] (unique Hive key), [saveState] (serialize), and
/// [restoreState] (deserialize). The game calls these automatically.
mixin Persistable on Component {
  /// Unique key for this component's saved state.
  String get saveKey;

  /// Serialize current state to a JSON-compatible map.
  Map<String, dynamic> saveState();

  /// Restore state from a previously saved map.
  /// Called before the component is mounted.
  void restoreState(Map<String, dynamic> state);
}
