import 'dart:async';

import 'package:flame/components.dart';

import '../../data/world_state.dart';
import '../../data/world_state_repository.dart';
import '../components/camera.dart';
import '../events.dart';
import '../world/world_map.dart';
import 'world_streamer.dart';

/// Owns persistable world state: collected coin indices, the dirty flag,
/// and the writer. Subscribes to the events that mutate persistable
/// state — [CoinCollected], [WalkStopped], [WorldExtended] — coalesces
/// writes to one per frame in [update], and exposes [flush] for lifecycle
/// hooks that can't wait for the next tick.
///
/// Pulled out of `LexawayGame` so the game class stops being a kitchen
/// sink for persistence state. [CoinManager] still holds a reference to
/// [collectedCoins] (shared mutable Set) so its spawn loop can skip items
/// that have already been collected.
class WorldStatePersister extends Component {
  final WorldStateRepository repository;

  /// Collected coin item indices. Shared with [CoinManager] — it reads
  /// this Set in its spawn loop to dedup against saved pickups. We mutate
  /// it here in the [CoinCollected] handler.
  final Set<int> collectedCoins;

  /// Used claw machine item indices. Shared with [ClawMachineManager],
  /// same shape as [collectedCoins].
  final Set<int> usedClawMachines;

  final Camera _camera;
  final WorldMap _worldMap;
  final WorldStreamer _worldStreamer;
  final GameEvents _events;

  bool _dirty = false;

  StreamSubscription<GameEvent>? _sub;

  WorldStatePersister({
    required this.repository,
    required Camera camera,
    required WorldMap worldMap,
    required WorldStreamer worldStreamer,
    required GameEvents events,
    Iterable<int> initialCollectedCoins = const [],
    Iterable<int> initialUsedClawMachines = const [],
  })  : _camera = camera,
        _worldMap = worldMap,
        _worldStreamer = worldStreamer,
        _events = events,
        collectedCoins = {...initialCollectedCoins},
        usedClawMachines = {...initialUsedClawMachines};

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case CoinCollected(:final itemIndex):
        collectedCoins.add(itemIndex);
        _dirty = true;
      case ClawMachineCompleted(:final itemIndex):
        usedClawMachines.add(itemIndex);
        _dirty = true;
      case WalkStopped():
      case WorldExtended():
        _dirty = true;
      default:
        break;
    }
  }

  @override
  void update(double dt) {
    if (_dirty) _write();
  }

  /// Immediate synchronous write. Call from lifecycle hooks (pause,
  /// dispose) where [update] may never run again before the process is
  /// torn down, or from boot to persist initial state.
  ///
  /// Safe to call before this component has been mounted — all
  /// collaborators are passed in at construction, so the snapshot doesn't
  /// depend on any `late` field being initialized first.
  void flush() {
    _write();
  }

  void _write() {
    _dirty = false;
    repository.save(_snapshot());
  }

  WorldState _snapshot() => WorldState(
        seed: _worldMap.seed,
        extensions: _worldStreamer.extensions,
        scrollOffset: _camera.scrollOffset,
        collectedCoins: collectedCoins.toList(),
        usedClawMachines: usedClawMachines.toList(),
      );

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
