import 'package:flame/components.dart';

import '../creature.dart';

/// Base class for composable creature behaviors. Each behavior is a child
/// component of [Creature] and can read/write parent state through Flame's
/// [ParentIsA] mixin.
abstract class CreatureBehaviorComponent extends Component
    with ParentIsA<Creature> {
  /// Whether this behavior has exclusive control (e.g. fleeing). Siblings
  /// yield when any is exclusive; the creature layer uses it to suppress
  /// respawning.
  bool get isExclusive => false;
}
