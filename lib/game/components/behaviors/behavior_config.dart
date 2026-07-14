import 'creature_behavior_component.dart';
import 'flee_behavior.dart';
import 'flight_behavior.dart';
import 'ground_anchor_behavior.dart';
import 'idle_hop_behavior.dart';

/// Const-constructible config that produces a [CreatureBehaviorComponent].
/// Lives on [CreatureSpriteDef] so biome registry entries stay fully const.
abstract class BehaviorConfig {
  const BehaviorConfig();
  CreatureBehaviorComponent create();
}

/// Config for [GroundAnchorBehavior].
class GroundAnchorConfig extends BehaviorConfig {
  /// Transparent rows beneath the feet in the sprite frame; compensated so
  /// the feet land on the ground line.
  final double footPadding;

  const GroundAnchorConfig({this.footPadding = 0});

  @override
  GroundAnchorBehavior create() =>
      GroundAnchorBehavior(footPadding: footPadding);
}

/// Config for [IdleHopBehavior].
class IdleHopConfig extends BehaviorConfig {
  final double minInterval;
  final double maxInterval;

  const IdleHopConfig({
    this.minInterval = 4.0,
    this.maxInterval = 9.0,
  });

  @override
  IdleHopBehavior create() =>
      IdleHopBehavior(minInterval: minInterval, maxInterval: maxInterval);
}

/// Config for [FleeBehavior].
class FleeConfig extends BehaviorConfig {
  final double speed;
  final double triggerTiles;

  const FleeConfig({
    this.speed = 120.0,
    this.triggerTiles = 2.0,
  });

  @override
  FleeBehavior create() => FleeBehavior(speed: speed, triggerTiles: triggerTiles);
}

/// Config for [FlightBehavior].
class FlightConfig extends BehaviorConfig {
  /// Altitude range above the ground (world px). Each creature picks a
  /// random altitude in [minAltitude, maxAltitude] on spawn, seeded by its
  /// item index so it's stable across frames.
  final double minAltitude;
  final double maxAltitude;
  final double bobAmplitude;
  final double bobFrequency;

  /// Constant horizontal drift in world px/sec. Negative drifts leftward
  /// (toward the player), positive drifts rightward (ahead of the player).
  final double driftSpeed;

  /// Horizontal sinusoidal wobble for a meandering, non-linear flutter.
  final double swayAmplitude;
  final double swayFrequency;

  const FlightConfig({
    required this.minAltitude,
    required this.maxAltitude,
    this.bobAmplitude = 6.0,
    this.bobFrequency = 1.5,
    this.driftSpeed = 0.0,
    this.swayAmplitude = 0.0,
    this.swayFrequency = 1.0,
  });

  @override
  FlightBehavior create() => FlightBehavior(
    minAltitude: minAltitude,
    maxAltitude: maxAltitude,
    bobAmplitude: bobAmplitude,
    bobFrequency: bobFrequency,
    driftSpeed: driftSpeed,
    swayAmplitude: swayAmplitude,
    swayFrequency: swayFrequency,
  );
}
