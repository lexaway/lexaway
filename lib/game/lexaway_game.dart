import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/hive_keys.dart';
import 'audio_manager.dart';
import 'components/coin_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/speech_bubble.dart';
import 'components/speech_messages.dart';
import 'components/wind_lines.dart';
import 'movement_controller.dart';
import 'world/biome_registry.dart';
import 'world/world_generator.dart';
import 'world/world_map.dart';
import 'world/world_renderer.dart';

class LexawayGame extends FlameGame with HasCollisionDetection {
  static const double pixelScale = 4.0;
  static const double groundLevel = 0.35;

  // Three tiles at 4x scale = 192px. Walk them in ~2.4s.
  static const double walkSpeed = 80;
  static const double walkTarget = 3 * 16 * pixelScale;
  static const double cloudDrift = 1.5;

  final Box hiveBox;
  final String characterPath;
  String _locale;

  LexawayGame({
    required this.hiveBox,
    String locale = 'en',
    required this.characterPath,
  }) : _locale = locale;

  String get locale => _locale;
  set locale(String value) {
    if (value == _locale) return;
    _locale = value;
    SpeechMessages.load(value);
  }

  late WorldMap worldMap;
  late WorldRenderer worldRenderer;
  late Player player;
  late Ground ground;
  late ParallaxComponent parallaxComponent;
  late SpeechBubble speechBubble;
  late CoinManager coinManager;
  late WindLines windLines;
  late MovementController movementController;

  /// Coin item indices the player has already collected.
  final Set<int> collectedCoins = {};

  /// How many extension batches have been appended.
  int _worldExtensions = 0;

  Function(int value)? onCoinCollected;
  Function(int steps)? onStepTaken;

  @override
  Color backgroundColor() => const Color(0xFF50BBFF);

  @override
  Future<void> onLoad() async {
    final saved = _loadWorldState();
    final seed = saved?['seed'] as int? ?? Random().nextInt(1 << 32);
    _worldExtensions = saved?['extensions'] as int? ?? 0;

    worldMap = WorldGenerator().generate(seed);
    // Replay extensions with the same seeds used during original gameplay.
    final targetExtensions = _worldExtensions;
    _worldExtensions = 0;
    for (var i = 0; i < targetExtensions; i++) {
      _worldExtensions++;
      _extendWorld();
    }

    final initialBiome = BiomeRegistry.get(worldMap.segments.first.biome);
    final parallaxHeight = size.y * groundLevel + 16 * pixelScale - 40;
    parallaxComponent = await loadParallaxComponent(
      initialBiome.parallaxLayers.map(ParallaxImageData.new).toList(),
      baseVelocity: Vector2.zero(),
      velocityMultiplierDelta: Vector2(1.4, 0),
      fill: LayerFill.height,
      filterQuality: FilterQuality.none,
      size: Vector2(size.x, parallaxHeight),
    );
    add(parallaxComponent);

    ground = Ground(worldMap: worldMap)..priority = 1;
    if (saved != null) {
      ground.scrollOffset = (saved['scroll_offset'] as num?)?.toDouble() ?? 0;
    }
    add(ground);

    final savedCoins = saved?['collected_coins'] as List?;
    if (savedCoins != null) {
      collectedCoins.addAll(savedCoins.cast<int>());
    }

    worldRenderer = WorldRenderer(worldMap)..priority = 1;
    add(worldRenderer);

    coinManager = CoinManager(worldMap: worldMap, collectedCoins: collectedCoins)
      ..priority = 1
      ..onCoinCollected = (value) => onCoinCollected?.call(value);
    add(coinManager);

    player = Player(spritePath: characterPath)..priority = 2;
    await add(player);
    player.play(DinoAnim.scan);

    windLines = WindLines()..priority = 2;
    add(windLines);

    speechBubble = SpeechBubble()..priority = 3;
    add(speechBubble);

    movementController = MovementController()
      ..onStepTaken = (steps) => onStepTaken?.call(steps);
    add(movementController);

    await AudioManager.instance.preload();
    await SpeechMessages.load('en');
    if (locale != 'en') await SpeechMessages.load(locale);

    // Persist the seed on first run.
    if (saved == null) saveWorldState();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gentle cloud drift independent of player movement.
    final layers = parallaxComponent.parallax!.layers;
    layers[1].update(Vector2(cloudDrift * dt, 0), dt);
    layers[2].update(Vector2(cloudDrift * 1.8 * dt, 0), dt);

    // Lazy world extension: if player is within 200 tiles of the end,
    // generate another batch.
    final tilePx = 16.0 * pixelScale;
    if (ground.scrollOffset + 200 * tilePx > worldMap.totalLengthPx) {
      _worldExtensions++;
      _extendWorld();
      saveWorldState();
    }
  }

  void correctAnswer({required int streak, required String answer}) {
    movementController.correctAnswer(streak: streak, answer: answer);
  }

  void wrongAnswer() {
    movementController.wrongAnswer();
  }

  /// Append 1000 more tiles to the world using a derived seed.
  void _extendWorld() {
    final extensionSeed = worldMap.seed + _worldExtensions;
    final extension = WorldGenerator().generate(
      extensionSeed,
      totalTiles: 1000,
      startTile: worldMap.totalTiles,
      startIndex: worldMap.nextItemIndex,
    );
    worldMap.segments.addAll(extension.segments);
    worldMap.nextItemIndex = extension.nextItemIndex;
  }

  Map<String, dynamic>? _loadWorldState() {
    try {
      final saved = hiveBox.get(HiveKeys.world) as Map?;
      if (saved == null) return null;
      return Map<String, dynamic>.from(saved);
    } catch (_) {
      return null;
    }
  }

  /// Save world state to Hive. Called after walk completion,
  /// coin collection, and on app lifecycle events.
  void saveWorldState() {
    hiveBox.put(HiveKeys.world, {
      'seed': worldMap.seed,
      'extensions': _worldExtensions,
      'scroll_offset': ground.scrollOffset,
      'collected_coins': collectedCoins.toList(),
    });
  }
}
