import 'dart:math';

import '../models/question.dart';
import 'pack_database.dart';
import 'sm2.dart';

class QuestionSource {
  final PackDatabase? _db;
  final String? _difficulty;
  final Random _rng = Random();

  List<Question> _fresh;
  List<Question> _review;
  int _freshIndex = 0;
  int _reviewIndex = 0;

  /// How often to serve a review item (e.g. 0.33 = every 3rd question).
  final double reviewRatio;
  int _sinceLastReview = 0;

  QuestionSource(
    PackDatabase db,
    List<Question> initialFresh, {
    List<Question> initialReview = const [],
    this.reviewRatio = 0.25,
    String? difficulty,
  })  : _db = db,
        _difficulty = difficulty,
        _fresh = List.of(initialFresh),
        _review = List.of(initialReview) {
    _fresh.shuffle(_rng);
    _review.shuffle(_rng);
  }

  /// For tests/fakes — no database, just cycles the given list forever.
  QuestionSource.static(List<Question> questions)
      : _db = null,
        _difficulty = null,
        _fresh = List.of(questions),
        _review = [],
        reviewRatio = 0.0 {
    _fresh.shuffle(_rng);
  }

  bool get hasQuestions => _fresh.isNotEmpty || _review.isNotEmpty;

  Question get current {
    if (_servingReview) return _review[_reviewIndex];
    return _fresh[_freshIndex];
  }

  bool get _servingReview {
    if (_review.isEmpty || _reviewIndex >= _review.length) return false;
    if (_fresh.isEmpty) return true;
    if (reviewRatio <= 0) return false;
    return _sinceLastReview >= (1 / reviewRatio).round();
  }

  /// Advance to the next question, reloading from the database when
  /// either queue is exhausted.
  Future<Question> advance() async {
    if (_servingReview) {
      _reviewIndex++;
      _sinceLastReview = 0;
      if (_reviewIndex >= _review.length) {
        await _reloadReview();
      }
    } else {
      _freshIndex++;
      _sinceLastReview++;
      if (_freshIndex >= _fresh.length) {
        await _reloadAll();
      }
    }
    return current;
  }

  /// Returns up to [count] upcoming questions after the current one,
  /// without advancing the index. Returns fewer near batch boundaries.
  List<Question> peek(int count) {
    final result = <Question>[];
    // Peek within the active queue only — good enough for TTS prefetch.
    if (_servingReview) {
      for (var i = 1; i <= count && _reviewIndex + i < _review.length; i++) {
        result.add(_review[_reviewIndex + i]);
      }
    } else {
      for (var i = 1; i <= count && _freshIndex + i < _fresh.length; i++) {
        result.add(_fresh[_freshIndex + i]);
      }
    }
    return result;
  }

  /// Record the player's answer: run SM-2 and write back to the database.
  /// Fire-and-forget from the UI — don't await this in setState.
  Future<void> recordAnswer(Question q, {required bool correct}) async {
    if (_db == null) return;
    final result = sm2(q.easiness, q.intervalDays, q.repetitions,
        correct: correct);
    await _db.updateSm2(
      q.id,
      easiness: result.easiness,
      intervalDays: result.intervalDays,
      repetitions: result.repetitions,
      nextReview: result.nextReview,
    );
  }

  Future<void> _reloadAll() async {
    if (_db == null) {
      _fresh.shuffle(_rng);
      _freshIndex = 0;
      return;
    }
    try {
      final freshBatch =
          await _db.loadQuestions(difficulty: _difficulty, limit: 200);
      if (freshBatch.isNotEmpty) _fresh = freshBatch;
    } catch (_) {
      // DB read failed — reshuffle existing batch rather than getting stuck.
    }
    _fresh.shuffle(_rng);
    _freshIndex = 0;
    await _reloadReview();
  }

  Future<void> _reloadReview() async {
    if (_db == null || reviewRatio <= 0) {
      _review = [];
      _reviewIndex = 0;
      return;
    }
    try {
      _review =
          await _db.loadReviewQuestions(difficulty: _difficulty, limit: 50);
    } catch (_) {
      _review = [];
    }
    _review.shuffle(_rng);
    _reviewIndex = 0;
  }
}
