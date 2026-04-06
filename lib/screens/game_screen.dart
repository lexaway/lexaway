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

class _GameScreenState extends ConsumerState<GameScreen> {
  final _game = LexawayGame();

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
