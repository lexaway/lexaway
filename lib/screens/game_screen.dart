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
  LexawayGame? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_game == null) {
      _game = LexawayGame(
        hiveBox: ref.read(hiveBoxProvider),
        locale: locale,
      );
      _game!.onCoinCollected = (value) {
        ref.read(coinProvider.notifier).add(value);
      };
    } else {
      _game!.locale = locale;
    }
  }

  @override
  void dispose() {
    // Lifecycle observer already saves on pause/inactive before dispose,
    // but save again in case of direct navigation without backgrounding.
    try {
      _game?.walkController.finishWalk();
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
      _game?.walkController.finishWalk();
      _game?.saveWorldState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final questions = ref.watch(activePackProvider).valueOrNull ?? [];

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
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
              game: game,
              questions: questions,
            ),
          ),
        ],
      ),
    );
  }
}
