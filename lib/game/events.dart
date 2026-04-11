import 'dart:async';

import 'components/coin.dart' show CoinType;

/// Typed game event channel. Sibling components subscribe to the events they
/// care about instead of reaching across the tree via `game.*`.
///
/// Events are delivered synchronously (`sync: true`) so that listeners react
/// inside the same tick the event was emitted — this matters for animation
/// and scroll changes that need to take effect immediately on answer input.
sealed class GameEvent {
  const GameEvent();
}

/// Player answered correctly. Carries streak count and the answer string so
/// that dialogue can quote it back.
class AnswerCorrect extends GameEvent {
  final int streak;
  final String answer;
  const AnswerCorrect(this.streak, this.answer);
}

/// Player answered wrong.
class AnswerWrong extends GameEvent {
  const AnswerWrong();
}

/// Walk (or run) has just started from a standstill.
class WalkStarted extends GameEvent {
  final bool running;
  const WalkStarted({required this.running});
}

/// The dino was already walking/running and just changed gear.
class WalkSpeedChanged extends GameEvent {
  final bool running;
  const WalkSpeedChanged({required this.running});
}

/// Walk has fully stopped (remaining distance hit zero or movement cancelled).
///
/// [skipDistance] is non-zero only when the stop was caused by
/// [MovementController.finishMovement] — the ScrollController uses it to
/// fast-forward the ground scroll offset by the remaining walk distance.
class WalkStopped extends GameEvent {
  final double skipDistance;
  const WalkStopped({this.skipDistance = 0});
}

/// One or more footsteps fired. [count] is usually 1 but can be higher when
/// a movement is fast-forwarded via `finishMovement`.
class StepTaken extends GameEvent {
  final int count;
  const StepTaken(this.count);
}

/// A coin or diamond was collected.
class CoinCollected extends GameEvent {
  final CoinType type;
  final int value;
  final int itemIndex;
  const CoinCollected(this.type, this.value, this.itemIndex);
}

/// The animation system wants to surface idle chatter. DialogueController
/// picks the localized message.
class IdleChatterTriggered extends GameEvent {
  const IdleChatterTriggered();
}

/// A batch of additional world segments has been appended. Fired by
/// [WorldStreamer] whenever the player gets close to the end of the
/// generated map and a new chunk is lazily produced.
class WorldExtended extends GameEvent {
  const WorldExtended();
}

/// Thin broadcast wrapper. Use [on] to get a filtered stream of a specific
/// event subtype; use [emit] to publish.
class GameEvents {
  final StreamController<GameEvent> _ctrl =
      StreamController<GameEvent>.broadcast(sync: true);

  Stream<T> on<T extends GameEvent>() =>
      _ctrl.stream.where((e) => e is T).cast<T>();

  void emit(GameEvent event) => _ctrl.add(event);

  Future<void> dispose() => _ctrl.close();
}
