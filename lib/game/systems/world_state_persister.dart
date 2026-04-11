import 'dart:async';

import 'package:flame/components.dart';

import '../../data/world_state.dart';
import '../../data/world_state_repository.dart';
import '../events.dart';
import '../lexaway_game.dart';

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
class WorldStatePersister extends Component with HasGameReference<LexawayGame> {
  final WorldStateRepository repository;

  /// Collected coin item indices. Shared with [CoinManager] — it reads
  /// this Set in its spawn loop to dedup against saved pickups. We mutate
  /// it here in the [CoinCollected] handler.
  final Set<int> collectedCoins;

  bool _dirty = false;

  StreamSubscription<GameEvent>? _sub;

  WorldStatePersister({
    required this.repository,
    Iterable<int> initialCollectedCoins = const [],
  }) : collectedCoins = {...initialCollectedCoins};

  @override
  void onMount() {
    super.onMount();
    _sub = game.events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case CoinCollected(:final itemIndex):
        collectedCoins.add(itemIndex);
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
  /// Callers must ensure the game's late fields ([worldMap], [ground],
  /// [worldStreamer]) are initialized — during `onLoad`, this means
  /// calling after those are set up.
  ///
  /// Safe to call before this component has been mounted: Flame's
  /// `add()` wires up the parent pointer synchronously, so `findGame()`
  /// (used by `HasGameReference.game`) resolves even pre-mount. The
  /// boot-time first-run save in `LexawayGame.onLoad` relies on this —
  /// don't "fix" it by deferring the call until after onLoad returns.
  void flush() {
    _write();
  }

  void _write() {
    _dirty = false;
    repository.save(_snapshot());
  }

  WorldState _snapshot() => WorldState(
        seed: game.worldMap.seed,
        extensions: game.worldStreamer.extensions,
        scrollOffset: game.ground.scrollOffset,
        collectedCoins: collectedCoins.toList(),
      );

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
