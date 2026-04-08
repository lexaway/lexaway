import 'package:flame/components.dart';

import '../lexaway_game.dart';
import '../world/world_map.dart';
import 'coin.dart';

/// Materializes coins from the pre-generated [WorldMap] as the player scrolls.
/// Tracks collected coins by index so they don't reappear after restart.
class CoinManager extends Component with HasGameReference<LexawayGame> {
  static const int _maxSpawnsPerFrame = 5;

  final WorldMap worldMap;
  final Set<int> collectedCoins;

  /// Track which item indices are currently on screen.
  final Set<int> _activeIndices = {};

  double _lastOffset = 0;

  Function(int value)? onCoinCollected;

  CoinManager({required this.worldMap, required this.collectedCoins});

  @override
  void onMount() {
    super.onMount();
    _lastOffset = game.ground.scrollOffset;
  }

  @override
  void update(double dt) {
    final offset = game.ground.scrollOffset;
    final moved = offset != _lastOffset;
    _lastOffset = offset;

    if (moved) {
      final startX = offset - 64;
      final endX = offset + game.size.x + 64;

      var spawned = 0;
      for (final item in worldMap.itemsInRange(startX, endX)) {
        if (item.category != ItemCategory.coin) continue;
        if (_activeIndices.contains(item.index)) continue;
        if (collectedCoins.contains(item.index)) continue;
        if (spawned >= _maxSpawnsPerFrame) break;

        final type = item.name == 'diamond' ? CoinType.diamond : CoinType.coin;
        final coin = Coin(type: type, worldX: item.worldX, itemIndex: item.index)
          ..onCollected = _onCoinCollected;
        _activeIndices.add(item.index);
        add(coin);
        spawned++;
      }
    }

    // Position & cull
    for (final coin in children.query<Coin>()) {
      coin.position.x = coin.worldX - offset;

      if (coin.position.x + coin.size.x < -64) {
        _activeIndices.remove(coin.itemIndex);
        coin.removeFromParent();
      }
    }
  }

  void _onCoinCollected(int value, int itemIndex) {
    collectedCoins.add(itemIndex);
    _activeIndices.remove(itemIndex);
    onCoinCollected?.call(value);
    game.saveWorldState();
  }
}
