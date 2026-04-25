/// Lightweight SM-2 spaced repetition algorithm.
///
/// Takes the current card state + a quality grade (0–5), returns the
/// updated state. Stateless and pure — no side effects, no dependencies.
library;

import 'day_key.dart';

typedef Sm2State = ({
  double easiness,
  int intervalDays,
  int repetitions,
  String nextReview,
});

Sm2State sm2(
  double easiness,
  int intervalDays,
  int repetitions, {
  required bool correct,
}) {
  // SM-2 quality: correct = 4 (remembered with effort), wrong = 1 (total blank).
  final q = correct ? 4 : 1;

  var ef = easiness + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (ef < 1.3) ef = 1.3;

  int newInterval;
  int newReps;
  if (!correct) {
    newReps = 0;
    newInterval = 1;
  } else {
    newReps = repetitions + 1;
    if (newReps == 1) {
      newInterval = 1;
    } else if (newReps == 2) {
      newInterval = 6;
    } else {
      newInterval = (intervalDays * ef).round();
    }
  }

  final nextReview = dayKeyOf(DateTime.now().add(Duration(days: newInterval)));

  return (
    easiness: ef,
    intervalDays: newInterval,
    repetitions: newReps,
    nextReview: nextReview,
  );
}
