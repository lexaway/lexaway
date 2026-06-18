import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/data/sm2.dart';

void main() {
  group('SM-2 algorithm', () {
    test('first correct answer → interval 1', () {
      final result = sm2(2.5, 0, 0, correct: true);
      expect(result.intervalDays, 1);
      expect(result.repetitions, 1);
    });

    test('second correct answer → interval 6', () {
      final first = sm2(2.5, 0, 0, correct: true);
      final second = sm2(first.easiness, first.intervalDays, first.repetitions,
          correct: true);
      expect(second.intervalDays, 6);
      expect(second.repetitions, 2);
    });

    test('third correct answer scales by easiness', () {
      final first = sm2(2.5, 0, 0, correct: true);
      final second = sm2(first.easiness, first.intervalDays, first.repetitions,
          correct: true);
      final third = sm2(second.easiness, second.intervalDays, second.repetitions,
          correct: true);
      expect(third.intervalDays, (6 * third.easiness).round());
      expect(third.repetitions, 3);
    });

    test('incorrect resets repetitions and interval to 1', () {
      var state = sm2(2.5, 0, 0, correct: true);
      state = sm2(state.easiness, state.intervalDays, state.repetitions,
          correct: true);
      expect(state.repetitions, 2);

      final failed = sm2(state.easiness, state.intervalDays, state.repetitions,
          correct: false);
      expect(failed.repetitions, 0);
      expect(failed.intervalDays, 1);
    });

    test('easiness floors at 1.3', () {
      // Repeatedly fail to drive easiness down
      var ef = 2.5;
      var interval = 0;
      var reps = 0;
      for (var i = 0; i < 20; i++) {
        final result = sm2(ef, interval, reps, correct: false);
        ef = result.easiness;
        interval = result.intervalDays;
        reps = result.repetitions;
      }
      expect(ef, 1.3);
    });

    test('nextReview is a valid ISO date string', () {
      final result = sm2(2.5, 0, 0, correct: true);
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(result.nextReview), isTrue);
    });
  });
}
