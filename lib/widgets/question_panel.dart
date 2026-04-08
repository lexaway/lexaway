import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tts_manager.dart';
import '../game/lexaway_game.dart';
import '../theme/app_colors.dart';
import '../models/question.dart';
import '../providers.dart';

enum _AnswerState { unanswered, correct, wrong }

class QuestionPanel extends ConsumerStatefulWidget {
  final LexawayGame game;
  final List<Question> questions;
  const QuestionPanel({super.key, required this.game, required this.questions});

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

  List<String> _shuffleOptions(Question q) => List.of(q.options)..shuffle(_rng);

  void _onOptionTap(String option) {
    if (_answerState != _AnswerState.unanswered) return;

    setState(() {
      _selectedOption = option;
      if (option == _current.answer) {
        _answerState = _AnswerState.correct;
        ref.read(streakProvider.notifier).increment();
        final streak = ref.read(streakProvider);
        widget.game.correctAnswer(streak: streak, answer: _current.answer);
        if (ref.read(hapticsEnabledProvider)) HapticFeedback.lightImpact();
        Future.delayed(const Duration(milliseconds: 900), _advance);
      } else {
        _answerState = _AnswerState.wrong;
        ref.read(streakProvider.notifier).reset();
        widget.game.wrongAnswer();
        _shakeController.forward(from: 0);
        if (ref.read(hapticsEnabledProvider)) HapticFeedback.mediumImpact();
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
      return AppColors.successDark;
    }
    if (option == _current.answer) return AppColors.successLight;
    if (option == _selectedOption) return AppColors.error;
    return AppColors.successDark.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 15, 24, 40),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ui/panel_brown_bg.png'),
            centerSlice: Rect.fromLTRB(24, 24, 72, 72),
            filterQuality: FilterQuality.none,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: _answerState == _AnswerState.wrong ? 64 + 64 : 64,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/ui/panel_inset_bg.png',
                        ),
                        centerSlice: Rect.fromLTRB(12, 12, 84, 84),
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _current.translation,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPhrase(),
                          ],
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _buildSpeakerButton(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: _shuffledOptions.map((option) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onOptionTap(option),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _buttonColor(option),
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 6),
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
                ],
              ),
            ),
            Positioned(
              top: -30,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/ui/banner_red.png'),
                    centerSlice: Rect.fromLTRB(96, 0, 192, 96),
                    filterQuality: FilterQuality.none,
                  ),
                ),
                child: Text(
                  _buildProgressBar(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            if (_answerState == _AnswerState.wrong)
              Positioned(
                bottom: 8,
                right: 0,
                child: GestureDetector(
                  onTap: _advance,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/ui/fab_circle_bg.png'),
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _speak() {
    final ttsService = ref.read(ttsServiceProvider);
    final ttsManager = ref.read(ttsManagerProvider);
    final lang = ref.read(activePackProvider.notifier).activeLang;
    if (lang != null && ttsManager.isModelDownloaded(lang)) {
      final masterVol = ref.read(masterVolumeProvider);
      final ttsVol = ref.read(ttsVolumeProvider);
      ttsService.speak(
        _current.phrase,
        lang: lang,
        ttsManager: ttsManager,
        volume: masterVol * ttsVol,
      );
    }
  }

  Widget _buildSpeakerButton() {
    // Watch the provider state (not .notifier) so we rebuild when pack changes
    ref.watch(activePackProvider);
    final lang = ref.read(activePackProvider.notifier).activeLang;
    if (lang == null || !TtsManager.isSupported(lang)) {
      return const SizedBox.shrink();
    }
    final ttsManager = ref.watch(ttsManagerProvider);
    if (!ttsManager.isModelDownloaded(lang)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _speak,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.volume_up_rounded,
          color: AppColors.textPrimary.withValues(alpha: 0.5),
          size: 22,
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
        : AppColors.textPrimary;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _current.before,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: revealText,
            style: TextStyle(
              color: blankColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: _current.after,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              height: 1.1,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  String _buildProgressBar() {
    final total = _questions.length;
    final current = _questionIndex % total;
    final pos = (current * 4 / total).floor();
    final before = '-' * pos;
    final after = '-' * (4 - pos);
    return '$before*$after';
  }
}
