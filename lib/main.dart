import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game/lexaway_game.dart';
import 'models/question.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const LexawayApp());
}

class LexawayApp extends StatelessWidget {
  const LexawayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = LexawayGame();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.pixelifySansTextTheme(),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: game),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _StreakBar(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: QuestionPanel(game: game),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 8, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _streakNotifier,
            builder: (_, streak, __) {
              if (streak == 0) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\u{1F525} $streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final _streakNotifier = ValueNotifier<int>(0);

enum _AnswerState { unanswered, correct, wrong }

class QuestionPanel extends StatefulWidget {
  final LexawayGame game;
  const QuestionPanel({super.key, required this.game});

  @override
  State<QuestionPanel> createState() => _QuestionPanelState();
}

class _QuestionPanelState extends State<QuestionPanel>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late List<Question> _questions;
  int _questionIndex = 0;
  _AnswerState _answerState = _AnswerState.unanswered;
  String? _selectedOption;
  late List<String> _shuffledOptions;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _questions = List.of(mockQuestions)..shuffle(_rng);
    _shuffledOptions = _shuffleOptions(_questions[0]);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Question get _current => _questions[_questionIndex % _questions.length];

  List<String> _shuffleOptions(Question q) => List.of(q.options)..shuffle(_rng);

  void _onOptionTap(String option) {
    if (_answerState != _AnswerState.unanswered) return;

    setState(() {
      _selectedOption = option;
      if (option == _current.answer) {
        _answerState = _AnswerState.correct;
        _streakNotifier.value++;
        widget.game.correctAnswer();
        Future.delayed(const Duration(milliseconds: 900), _advance);
      } else {
        _answerState = _AnswerState.wrong;
        _streakNotifier.value = 0;
        _shakeController.forward(from: 0);
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      _questionIndex++;
      if (_questionIndex % _questions.length == 0) {
        _questions.shuffle(_rng);
      }
      _answerState = _AnswerState.unanswered;
      _selectedOption = null;
      _shuffledOptions = _shuffleOptions(_current);
    });
  }

  Color _buttonColor(String option) {
    if (_answerState == _AnswerState.unanswered) {
      return Colors.green.shade700;
    }
    if (option == _current.answer) return Colors.green.shade400;
    if (option == _selectedOption) return Colors.red.shade400;
    return Colors.green.shade700.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomPadding),
        decoration: BoxDecoration(
          color: Colors.brown.shade800.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Colors.brown.shade400, width: 3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Translation (muted, small)
            Text(
              _current.translation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            // Phrase with blank
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.brown.shade900.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildPhrase(),
            ),
            const SizedBox(height: 16),
            // Answer buttons — 3 across
            Row(
              children: _shuffledOptions.map((option) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => _onOptionTap(option),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonColor(option),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            // "Next" button on wrong answer
            if (_answerState == _AnswerState.wrong) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _advance,
                child: Text(
                  'next \u{2192}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhrase() {
    final parts = _current.phrase.split(_current.answer);
    final blankText = _answerState == _AnswerState.unanswered
        ? '____'
        : _current.answer;
    final blankColor = _answerState == _AnswerState.correct
        ? Colors.greenAccent
        : _answerState == _AnswerState.wrong
            ? Colors.orangeAccent
            : Colors.white;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: parts[0],
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          TextSpan(
            text: blankText,
            style: TextStyle(
              color: blankColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (parts.length > 1)
            TextSpan(
              text: parts[1],
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
