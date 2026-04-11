import 'dart:async';

import 'package:flame/components.dart';

import '../events.dart';
import '../world/scrolling_item_layer.dart';
import '../world/world_map.dart';
import 'coin.dart';
import 'coin_fly_effect.dart';

/// Materializes coins from the pre-generated [WorldMap] as the player scrolls.
/// Tracks collected coins by index so they don't reappear after restart, and
/// owns the "fly to HUD counter" visual effect spawned on pickup — this keeps
/// HUD layout knowledge out of [Coin].
class CoinManager extends ScrollingItemLayer<Coin> {
  /// Screen-space offset of the coin counter inside the HUD. Centralized
  /// here (not on [Coin]) so only one place in the game code knows where
  /// the counter lives.
  static final Vector2 _hudCounterOffset = Vector2(-60, 50);

  final Set<int> collectedCoins;

  StreamSubscription<GameEvent>? _sub;

  CoinManager({required super.worldMap, required this.collectedCoins})
      : super(
          category: ItemCategory.coin,
          spawnMarginPx: 64,
          cullMarginPx: 64,
          maxSpawnsPerFrame: 5,
        );

  @override
  Coin? createItem(PlacedItem item) {
    if (collectedCoins.contains(item.index)) return null;
    final type = item.name == 'diamond' ? CoinType.diamond : CoinType.coin;
    return Coin(type: type, worldX: item.worldX, itemIndex: item.index);
  }

  @override
  void onMount() {
    super.onMount();
    _sub = game.events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case CoinCollected(:final itemIndex):
        // [WorldStatePersister] also listens to CoinCollected and owns
        // the collectedCoins mutation + dirty flag. We just handle the
        // visual pickup effect here.
        //
        // Event is delivered synchronously, so the Coin is still
        // attached and its sprite state is still readable — spawn the
        // fly effect here rather than forcing Coin to know HUD
        // coordinates.
        final coin = activeItems.remove(itemIndex);
        if (coin != null && coin.animation != null) {
          game.add(
            CoinFlyEffect(
              start: coin.position.clone(),
              target: Vector2(game.size.x, 0) + _hudCounterOffset,
              animation: coin.animation!.clone(),
              spriteSize: coin.size.clone(),
            ),
          );
        }
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
