import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_source.dart';
import '../data/tts_manager.dart';
import '../game/lexaway_game.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../models/question.dart';
import '../providers.dart';
import 'mini_map.dart';

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

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
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
    await widget.source.advance();
    if (!mounted) return;
    setState(() {
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
                  Container(
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
                          child: _buildSpeakerButton(),
                        ),
                      ],
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
        padding: const EdgeInsets.all(AppSpacing.xs),
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

}
