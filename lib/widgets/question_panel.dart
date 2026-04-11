import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_source.dart';
import '../game/lexaway_game.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../models/question.dart';
import '../providers.dart';
import 'mini_map.dart';
import 'phrase_text.dart';
import 'tts_controller.dart';

enum _AnswerState { unanswered, correct, wrong }

class QuestionPanel extends ConsumerStatefulWidget {
  final LexawayGame game;
  final QuestionSource source;
  const QuestionPanel({super.key, required this.game, required this.source});

  @override
  ConsumerState<QuestionPanel> createState() => _QuestionPanelState();
}

class _QuestionPanelState extends ConsumerState<QuestionPanel>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  _AnswerState _answerState = _AnswerState.unanswered;
  String? _selectedOption;
  late List<String> _shuffledOptions;
  Timer? _advanceTimer;

  late final TtsController _tts;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _tts = TtsController(ref: ref, isMounted: () => mounted);
    _shuffledOptions = _shuffleOptions(widget.source.current);

    // Rebuild once the game finishes loading so the mini-map appears
    // without waiting for the first user interaction.
    if (!widget.game.isLoaded) {
      widget.game.loaded.then((_) {
        if (mounted) setState(() {});
      });
    }

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

    _tts.prefetch(_prefetchTexts());
    if (ref.read(autoPlayTtsProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speakSentence();
      });
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Question get _current => widget.source.current;

  List<String> _shuffleOptions(Question q) => List.of(q.options)..shuffle(_rng);

  void _onOptionTap(String option) {
    if (_answerState != _AnswerState.unanswered) return;

    final correct = option == _current.answer;
    widget.source.recordAnswer(_current, correct: correct);

    setState(() {
      _selectedOption = option;
      if (correct) {
        _answerState = _AnswerState.correct;
        ref.read(streakProvider.notifier).increment();
        final streak = ref.read(streakProvider);
        widget.game.correctAnswer(streak: streak, answer: _current.answer);
        if (ref.read(hapticsEnabledProvider)) HapticFeedback.lightImpact();
        _advanceTimer?.cancel();
        _advanceTimer = Timer(const Duration(milliseconds: 900), _advance);
      } else {
        _answerState = _AnswerState.wrong;
        ref.read(streakProvider.notifier).reset();
        widget.game.wrongAnswer();
        _shakeController.forward(from: 0);
        if (ref.read(hapticsEnabledProvider)) HapticFeedback.mediumImpact();
      }
    });
  }

  Future<void> _advance() async {
    if (!mounted) return;
    _tts.invalidatePending();
    await widget.source.advance();
    if (!mounted) return;
    setState(() {
      _answerState = _AnswerState.unanswered;
      _selectedOption = null;
      _shuffledOptions = _shuffleOptions(_current);
    });
    _tts.prefetch(_prefetchTexts());
    if (ref.read(autoPlayTtsProvider)) {
      _speakSentence();
    }
  }

  Color _buttonColor(String option) {
    if (_answerState == _AnswerState.unanswered) {
      return AppColors.successDark;
    }
    if (option == _current.answer) return AppColors.successLight;
    if (option == _selectedOption) return AppColors.error;
    return AppColors.successDark.withValues(alpha: 0.4);
  }

  // -- TTS --

  List<String> _prefetchTexts() {
    final texts = <String>[_current.phrase, ..._current.words];
    for (final q in widget.source.peek(2)) {
      texts.add(q.phrase);
      texts.addAll(q.words);
    }
    return texts;
  }

  void _speakSentence() => _tts.speak(_current.phrase);
  void _speakWord(String word) => _tts.speak(word);

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
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 40),
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
                bottom: _answerState == _AnswerState.wrong ? AppSpacing.xxxl + AppSpacing.xxxl : AppSpacing.xxxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hand-tuned: clears the overlapping banner.
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: _speakSentence,
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
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
                              const SizedBox(height: AppSpacing.sm),
                              _buildPhrase(),
                            ],
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: _buildSpeakerIcon(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    children: _shuffledOptions.map((option) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onOptionTap(option),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _buttonColor(option),
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
              top: -AppSpacing.sm,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/ui/banner_red.png'),
                    centerSlice: Rect.fromLTRB(96, 0, 192, 96),
                    filterQuality: FilterQuality.none,
                  ),
                ),
                child: widget.game.isLoaded
                    ? MiniMap(
                        worldMap: widget.game.worldMap,
                        scrollOffset: widget.game.ground.scrollOffset,
                      )
                    : const SizedBox(height: AppSpacing.md),
              ),
            ),
            if (_answerState == _AnswerState.wrong)
              Positioned(
                bottom: AppSpacing.sm,
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

  /// Visual-only speaker icon (the whole inset panel is tappable now).
  Widget _buildSpeakerIcon() {
    if (ref.watch(activeTtsLangProvider) == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Icon(
        Icons.volume_up_rounded,
        color: AppColors.textPrimary.withValues(alpha: 0.5),
        size: 22,
      ),
    );
  }

  Widget _buildPhrase() {
    final blankColor = _answerState == _AnswerState.correct
        ? Colors.greenAccent
        : _answerState == _AnswerState.wrong
        ? Colors.orangeAccent
        : AppColors.textPrimary;

    return PhraseText(
      phrase: _current.phrase,
      blankIndex: _current.blankIndex,
      answer: _current.answer,
      revealed: _answerState != _AnswerState.unanswered,
      blankColor: blankColor,
      textColor: AppColors.textPrimary,
      onTapWord: _speakWord,
    );
  }
}
