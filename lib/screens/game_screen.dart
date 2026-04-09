import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_keys.dart';
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
      final box = ref.read(hiveBoxProvider);
      final charKey = box.get(HiveKeys.character(lang)) as String? ?? 'female/doux';
      final character = CharacterInfo.fromKey(charKey);

      _game = LexawayGame(
        hiveBox: box,
        locale: dinoLocale,
        characterPath: character.basePath,
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
    // Lifecycle observer already saves on pause/inactive before dispose,
    // but save again in case of direct navigation without backgrounding.
    try {
      _game?.movementController.finishMovement();
      _game?.saveWorldState();
    } catch (_) {
      // Game components may already be detached during teardown.
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _game?.movementController.finishMovement();
      _game?.saveWorldState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final source = ref.watch(activePackProvider).valueOrNull;

    // Sync volume settings to the audio singleton
    final audio = AudioManager.instance;
    audio.masterVolume = ref.watch(masterVolumeProvider);
    audio.sfxVolume = ref.watch(sfxVolumeProvider);

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
