import 'dart:async';

import 'audio_manager.dart' show Terrain;
import 'components/coin.dart' show CoinType;
import 'world/world_map.dart' show BiomeType;

/// Events are delivered synchronously (`sync: true`) so listeners react in the
/// same tick they were emitted — needed for animation/scroll changes that must
/// take effect immediately on answer input.
sealed class GameEvent {
  const GameEvent();
}

class AnswerCorrect extends GameEvent {
  final int streak;
  final String answer;
  const AnswerCorrect(this.streak, this.answer);
}

class AnswerWrong extends GameEvent {
  const AnswerWrong();
}

class WalkStarted extends GameEvent {
  final bool running;
  const WalkStarted({required this.running});
}

class WalkSpeedChanged extends GameEvent {
  final bool running;
  const WalkSpeedChanged({required this.running});
}

class WalkStopped extends GameEvent {
  /// Non-zero only when [MovementController.finishMovement] caused the stop —
  /// WorldScrollController uses it to fast-forward the ground scroll offset.
  final double skipDistance;
  const WalkStopped({this.skipDistance = 0});
}

class StepTaken extends GameEvent {
  final int count;
  final Terrain terrain;
  const StepTaken(this.count, {this.terrain = Terrain.grass});
}

class CoinCollected extends GameEvent {
  final CoinType type;
  final int value;
  final int itemIndex;
  const CoinCollected(this.type, this.value, this.itemIndex);
}

class IdleChatterTriggered extends GameEvent {
  const IdleChatterTriggered();
}

class BiomeChanged extends GameEvent {
  final BiomeType previous;
  final BiomeType current;
  const BiomeChanged({required this.previous, required this.current});
}

class WorldExtended extends GameEvent {
  const WorldExtended();
}

class ClawMachineEntered extends GameEvent {
  final int itemIndex;
  final double worldX;
  const ClawMachineEntered({required this.itemIndex, required this.worldX});
}

class ClawMachineCompleted extends GameEvent {
  final int itemIndex;
  final bool won;
  final int spheresWon;
  final int coinsSpent;
  final String? prizeId;
  const ClawMachineCompleted({
    required this.itemIndex,
    required this.won,
    required this.spheresWon,
    required this.coinsSpent,
    this.prizeId,
  });
}

class GameEvents {
  final StreamController<GameEvent> _ctrl =
      StreamController<GameEvent>.broadcast(sync: true);

  Stream<T> on<T extends GameEvent>() =>
      _ctrl.stream.where((e) => e is T).cast<T>();

  void emit(GameEvent event) => _ctrl.add(event);

  Future<void> dispose() => _ctrl.close();
}
