import 'dart:async';

import '../events.dart';
import '../world/scrolling_item_layer.dart';
import '../world/world_map.dart';
import 'claw_machine.dart';

/// Materializes claw machines from the [WorldMap] as the player scrolls.
/// Mirrors [CoinManager]; machines are marked "used" on
/// [ClawMachineCompleted] (win, lose, or decline) so they never re-spawn.
/// The persister writes that set to disk, deduping across restarts too.
class ClawMachineManager extends ScrollingItemLayer<ClawMachine> {
  /// Indices used this run, shared with the persister (which owns mutation);
  /// this layer reads it during spawn to dedup. Like [CoinManager.collectedCoins].
  final Set<int> usedClawMachines;

  final GameEvents _events;

  StreamSubscription<GameEvent>? _sub;

  ClawMachineManager({
    required super.worldMap,
    required super.camera,
    required GameEvents events,
    required this.usedClawMachines,
  })  : _events = events,
        super(
          category: ItemCategory.clawMachine,
          spawnMarginPx: 128,
          cullMarginPx: 64,
          maxSpawnsPerFrame: 1,
        );

  @override
  ClawMachine? createItem(PlacedItem item) {
    if (usedClawMachines.contains(item.index)) return null;
    return ClawMachine(worldX: item.worldX, itemIndex: item.index);
  }

  @override
  bool shouldSkip(int index) => usedClawMachines.contains(index);

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case ClawMachineCompleted(:final itemIndex):
        // Cull immediately so a still-colliding hitbox doesn't block the dino
        // after the encounter resolves. The persister writes itemIndex into
        // the shared [usedClawMachines] set for restart dedup.
        markCulled(itemIndex);
        activeItems.remove(itemIndex)?.removeFromParent();
      default:
        break;
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
