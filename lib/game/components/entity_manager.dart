import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../lexaway_game.dart';
import 'entity.dart';

/// Spawns scenery entities (trees, bushes, fences, etc.) along the ground
/// as the player walks, following the same world-coordinate pattern as coins.
class EntityManager extends Component with HasGameReference<LexawayGame> {
  static const int _minGapTiles = 8;
  static const int _maxGapTiles = 20;
  static const int _maxSpawnsPerFrame = 3;

  static const List<_WeightedEntity> _weights = [
    _WeightedEntity('bush', 25),
    _WeightedEntity('mushroom', 20),
    _WeightedEntity('round_tree', 15),
    _WeightedEntity('pine_tree', 15),
    _WeightedEntity('flower_tree', 10),
    _WeightedEntity('fence', 10),
    _WeightedEntity('flower_fence', 5),
  ];

  static final int _totalWeight =
      _weights.fold(0, (sum, w) => sum + w.weight);

  final _rng = Random();

  /// Loaded entity definitions: name → {sprite, widthTiles, heightTiles}.
  final Map<String, _EntityDef> _defs = {};

  double _nextSpawnAt = 0;
  double _lastOffset = 0;

  @override
  Future<void> onLoad() async {
    final jsonStr =
        await rootBundle.loadString('assets/images/entities/grassland.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final image = await game.images.load('entities/grassland.png');
    final entities = json['entities'] as Map<String, dynamic>;

    for (final entry in entities.entries) {
      final e = entry.value as Map<String, dynamic>;
      final src = (e['src'] as List).cast<int>();
      final sz = (e['size'] as List).cast<int>();

      _defs[entry.key] = _EntityDef(
        sprite: Sprite(
          image,
          srcPosition: Vector2(src[0].toDouble(), src[1].toDouble()),
          srcSize: Vector2(sz[0].toDouble(), sz[1].toDouble()),
        ),
        widthTiles: e['widthTiles'] as int,
        heightTiles: e['heightTiles'] as int,
      );
    }
  }

  @override
  void onMount() {
    super.onMount();
    _lastOffset = game.ground.scrollOffset;
    _nextSpawnAt = game.ground.scrollOffset + game.size.x + 64;
  }

  @override
  void update(double dt) {
    final offset = game.ground.scrollOffset;
    final moved = offset != _lastOffset;
    _lastOffset = offset;

    if (moved) {
      final spawnHorizon = offset + game.size.x + 128;
      var spawned = 0;
      while (_nextSpawnAt < spawnHorizon && spawned < _maxSpawnsPerFrame) {
        _spawnAt(_nextSpawnAt);
        _nextSpawnAt += _randomGap();
        spawned++;
      }
    }

    // Position & cull
    for (final entity in children.query<Entity>()) {
      entity.position.x = entity.worldX - offset;

      if (entity.position.x + entity.spriteSize.x < -128) {
        entity.removeFromParent();
      }
    }
  }

  void _spawnAt(double worldX) {
    final name = _pickRandom();
    final def = _defs[name];
    if (def == null) return;

    final scale = LexawayGame.pixelScale;
    final spriteSize = Vector2(
      def.widthTiles * 16.0 * scale,
      def.heightTiles * 16.0 * scale,
    );

    // Bottom edge sits on the ground surface
    final groundTop = game.size.y * LexawayGame.groundLevel;
    final y = groundTop - spriteSize.y;

    final entity = Entity(
      sprite: def.sprite,
      spriteSize: spriteSize,
      worldX: worldX,
    )..position.y = y;

    add(entity);
  }

  String _pickRandom() {
    var roll = _rng.nextInt(_totalWeight);
    for (final w in _weights) {
      roll -= w.weight;
      if (roll < 0) return w.name;
    }
    return _weights.last.name;
  }

  double _randomGap() =>
      (_minGapTiles + _rng.nextInt(_maxGapTiles - _minGapTiles + 1)) *
      16 *
      LexawayGame.pixelScale;
}

class _EntityDef {
  final Sprite sprite;
  final int widthTiles;
  final int heightTiles;

  _EntityDef({
    required this.sprite,
    required this.widthTiles,
    required this.heightTiles,
  });
}

class _WeightedEntity {
  final String name;
  final int weight;

  const _WeightedEntity(this.name, this.weight);
}
