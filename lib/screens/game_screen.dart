import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_font.dart';
import '../data/pack_manager.dart';
import '../game/audio_manager.dart';
import '../game/lexaway_game.dart';
import '../models/character.dart';
import '../providers.dart';
import '../widgets/question_panel.dart';
import '../widgets/hud_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LexawayGame? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = ref.read(activePackProvider.notifier).activeLang!;
    final dinoLocale = iso3to2[lang] ?? 'en';
    if (_game == null) {
      final repo = ref.read(worldStateRepositoryProvider);
      final charKey = ref.read(characterProvider(lang)) ?? 'female/doux';
      final character = CharacterInfo.fromKey(charKey);

      _game = LexawayGame(
        worldStateRepository: repo,
        locale: dinoLocale,
        characterPath: character.basePath,
        fontFamily: ref.read(fontProvider).family,
      );
      _game!.onCoinCollected = (value) {
        ref.read(coinProvider.notifier).add(value);
      };
      _game!.onStepTaken = (steps) {
        ref.read(stepsProvider.notifier).add(steps);
      };
    } else {
      _game!.locale = dinoLocale;
    }
  }

  @override
  void dispose() {
    // Lifecycle observer already flushes on pause/inactive before dispose,
    // but flush again in case of direct navigation without backgrounding.
    _flushGameState();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushGameState();
    }
  }

  /// Best-effort save during teardown / backgrounding. Both underlying calls
  /// can throw during teardown (finishMovement touches game components that
  /// may already be detached; flushWorldState goes through Hive and could
  /// surface disk errors) — neither should escape into the Flutter framework.
  void _flushGameState() {
    final game = _game;
    if (game == null) return;
    try {
      game.movementController.finishMovement();
    } catch (_) {
      // Components already detached; fall through to flush.
    }
    try {
      game.flushWorldState();
    } catch (_) {
      // Hive write failed during teardown; nothing useful we can do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final source = ref.watch(activePackProvider).valueOrNull;

    // Forward font selection changes from Settings into the running game so
    // the speech bubble updates without requiring a game rebuild.
    ref.listen<AppFont>(fontProvider, (prev, next) {
      _game?.fontFamily = next.family;
    });

    // Sync volume settings to the audio singleton
    ref.listen<double>(masterVolumeProvider, (prev, next) {
      AudioManager.instance.masterVolume = next;
    }, fireImmediately: true);
    ref.listen<double>(sfxVolumeProvider, (prev, next) {
      AudioManager.instance.sfxVolume = next;
    }, fireImmediately: true);

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
          Positioned(left: 0, right: 0, top: 0, child: const HudBar()),
          if (source != null)
            Positioned(
              left: 0,
              right: 0,
              top:
                  MediaQuery.of(context).size.height * LexawayGame.groundLevel +
                  64,
              bottom: -24,
              child: QuestionPanel(
                // Identity equality — new source on pack switch rebuilds the panel.
                key: ValueKey(source),
                game: game,
                source: source,
              ),
            ),
        ],
      ),
    );
  }
}
