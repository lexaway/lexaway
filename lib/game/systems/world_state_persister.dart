import 'dart:async';

import 'package:flame/components.dart';

import '../../data/world_state.dart';
import '../../data/world_state_repository.dart';
import '../components/camera.dart';
import '../events.dart';
import '../world/world_map.dart';
import 'world_streamer.dart';

/// Owns persistable world state. Coalesces writes to one per frame in
/// [update]; [flush] forces an immediate write for lifecycle hooks that
/// can't wait for the next tick.
class WorldStatePersister extends Component {
  final WorldStateRepository repository;

  /// Collected coin item indices. Shared mutable Set — [CoinManager] reads
  /// it in its spawn loop to dedup against saved pickups.
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

  /// Immediate synchronous write, for lifecycle hooks (pause, dispose) where
  /// [update] may never run again before teardown, or to persist boot state.
  /// Safe to call pre-mount: all collaborators are passed at construction.
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
