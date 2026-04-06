import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/lexaway_game.dart';
import '../models/question.dart';
import 'pack_manager_screen.dart';
import '../widgets/question_panel.dart';
import '../widgets/streak_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  const GameScreen({super.key, required this.questions});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _game = LexawayGame();

  void _openPackManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PackManagerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StreakBar(onLanguageTap: _openPackManager),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QuestionPanel(
              key: ValueKey(widget.questions),
              game: _game,
              questions: widget.questions,
            ),
          ),
        ],
      ),
    );
  }
}
