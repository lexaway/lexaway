import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/lexaway_game.dart';
import '../models/question.dart';
import '../providers.dart';

enum _AnswerState { unanswered, correct, wrong }

class QuestionPanel extends ConsumerStatefulWidget {
  final LexawayGame game;
  final List<Question> questions;
  const QuestionPanel({
    super.key,
    required this.game,
    required this.questions,
  });

  @override
  ConsumerState<QuestionPanel> createState() => _QuestionPanelState();
}

class _QuestionPanelState extends ConsumerState<QuestionPanel>
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
    _questions = List.of(widget.questions)..shuffle(_rng);
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

  List<String> _shuffleOptions(Question q) =>
      List.of(q.options)..shuffle(_rng);

  void _onOptionTap(String option) {
    if (_answerState != _AnswerState.unanswered) return;

    setState(() {
      _selectedOption = option;
      if (option == _current.answer) {
        _answerState = _AnswerState.correct;
        ref.read(streakProvider.notifier).increment();
        widget.game.correctAnswer();
        Future.delayed(const Duration(milliseconds: 900), _advance);
      } else {
        _answerState = _AnswerState.wrong;
        ref.read(streakProvider.notifier).reset();
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
            Text(
              _current.translation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
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
    final revealText = _answerState == _AnswerState.unanswered
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
            text: _current.before,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          TextSpan(
            text: revealText,
            style: TextStyle(
              color: blankColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: _current.after,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
