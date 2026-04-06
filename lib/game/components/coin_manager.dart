import 'dart:math';

import 'package:flame/components.dart';
import '../audio_manager.dart';
import '../lexaway_game.dart';
import '../persistable.dart';
import 'coin.dart';

class CoinManager extends Component
    with HasGameReference<LexawayGame>, Persistable {
  // Spawn roll thresholds (0..1)
  static const double diamondChance = 0.15;
  static const double clusterChance = 0.40; // cumulative: 15% diamond, 25% cluster, 60% single
  // Gap between spawn points: random 2–5 tiles
  static const int minGapTiles = 2;
  static const int maxGapTiles = 5; // inclusive upper bound
  // Max coins spawned per frame to prevent bursts after backgrounding
  static const int maxSpawnsPerFrame = 5;

  final _rng = Random();

  double _nextSpawnAt = 0;
  double _lastOffset = 0;
  bool _restored = false;

  Function(int value)? onCoinCollected;

  @override
  String get saveKey => 'coin_manager';

  @override
  Map<String, dynamic> saveState() => {
        'next_spawn_at': _nextSpawnAt,
        'coins': children
            .query<Coin>()
            .where((c) => !c.collected)
            .map((c) => c.toJson())
            .toList(),
      };

  @override
  void restoreState(Map<String, dynamic> state) {
    _nextSpawnAt = (state['next_spawn_at'] as num).toDouble();
    _restored = true;
    final coins = state['coins'] as List?;
    if (coins != null) {
      for (final e in coins) {
        add(Coin.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }
  }

  @override
  void onMount() {
    super.onMount();
    _lastOffset = game.ground.scrollOffset;
    if (!_restored) {
      _nextSpawnAt = game.ground.scrollOffset + game.size.x + 64;
    }
  }

  @override
  void update(double dt) {
    final offset = game.ground.scrollOffset;
    final moved = offset != _lastOffset;
    _lastOffset = offset;

    if (moved) {
      // Spawn coins ahead (max 5 per frame to prevent bursts)
      final spawnHorizon = offset + game.size.x + 64;
      var spawned = 0;
      while (_nextSpawnAt < spawnHorizon && spawned < maxSpawnsPerFrame) {
        _spawnAt(_nextSpawnAt);
        _nextSpawnAt += _randomGap();
        spawned++;
      }
    }

    // Position coins & check collection (always runs, even when idle)
    final playerCenterX = game.size.x * 0.25 + game.player.size.x * 0.5;

    for (final coin in children.query<Coin>()) {
      coin.position.x = coin.worldX - offset;

      // Collected when coin center reaches player center
      if (!coin.collected &&
          coin.position.x + coin.size.x * 0.5 <= playerCenterX) {
        coin.collected = true;
        final value = coin.type == CoinType.diamond ? 3 : 1;
        onCoinCollected?.call(value);
        if (coin.type == CoinType.diamond) {
          AudioManager.instance.playGem();
        } else {
          AudioManager.instance.playCoin();
        }
        coin.removeFromParent();
        game.saveWorldState();
        continue;
      }

      // Clean up coins that scrolled off-screen left
      if (coin.position.x + coin.size.x < -64) {
        coin.removeFromParent();
      }
    }
  }

  void _spawnAt(double worldX) {
    final roll = _rng.nextDouble();
    if (roll < diamondChance) {
      // Diamond
      add(Coin(type: CoinType.diamond, worldX: worldX));
    } else if (roll < clusterChance) {
      // 2-coin cluster
      add(Coin(type: CoinType.coin, worldX: worldX));
      add(Coin(type: CoinType.coin, worldX: worldX + 16 * LexawayGame.pixelScale));
    } else {
      // Single coin
      add(Coin(type: CoinType.coin, worldX: worldX));
    }
  }

  /// Random gap of 2–5 tiles (128–320px) between spawn points.
  double _randomGap() =>
      (minGapTiles + _rng.nextInt(maxGapTiles - minGapTiles + 1)) *
      16 *
      LexawayGame.pixelScale;
}
