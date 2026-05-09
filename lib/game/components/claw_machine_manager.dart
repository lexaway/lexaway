import 'dart:async';

import '../events.dart';
import '../world/scrolling_item_layer.dart';
import '../world/world_map.dart';
import 'claw_machine.dart';

/// Materializes claw machines from the pre-generated [WorldMap] as the
/// player scrolls. Mirrors [CoinManager], with one twist: machines are
/// marked "used" on [ClawMachineCompleted] (whether the player won, lost,
/// or declined the prompt) so they never re-spawn for the rest of the
/// session — and the persister writes that set to disk so they don't
/// re-spawn across restarts either.
class ClawMachineManager extends ScrollingItemLayer<ClawMachine> {
  /// Indices already used this run. Shared with the persister, exactly like
  /// [CoinManager.collectedCoins] — the persister owns mutation, this layer
  /// reads it during spawn to dedup.
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
        // Pull the cabinet off-screen immediately so the dino isn't blocked
        // by a still-colliding hitbox after the encounter resolves. The
        // persister writes itemIndex into [usedClawMachines] — shared
        // mutable Set — so this layer's spawn loop dedups across restarts.
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
