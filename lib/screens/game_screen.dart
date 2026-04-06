import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/lexaway_game.dart';
import '../providers.dart';
import '../widgets/question_panel.dart';
import '../widgets/streak_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late final LexawayGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = LexawayGame(hiveBox: ref.read(hiveBoxProvider));
    _game.onCoinCollected = (value) {
      ref.read(coinProvider.notifier).add(value);
    };
  }

  @override
  void dispose() {
    // Lifecycle observer already saves on pause/inactive before dispose,
    // but save again in case of direct navigation without backgrounding.
    try {
      _game.walkController.finishWalk();
      _game.saveWorldState();
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
      _game.walkController.finishWalk();
      _game.saveWorldState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(activePackProvider).valueOrNull ?? [];

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: const StreakBar(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuestionPanel(
              key: ValueKey(questions),
              game: _game,
              questions: questions,
            ),
          ),
        ],
      ),
    );
  }
}
