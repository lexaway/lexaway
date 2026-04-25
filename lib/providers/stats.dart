import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/day_key.dart';
import '../data/hive_keys.dart';
import 'bootstrap.dart';

/// Base class for simple Hive-backed int notifiers.
abstract class HiveIntNotifier extends Notifier<int> {
  String get key;
  int get defaultValue => 0;

  Box get _box => ref.read(hiveBoxProvider);

  @override
  int build() => _box.get(key, defaultValue: defaultValue) as int;

  void _save() => _box.put(key, state);
}

final streakProvider = NotifierProvider<StreakNotifier, int>(
  StreakNotifier.new,
);

class StreakNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.streak;

  void increment() {
    state++;
    _save();
    ref.read(bestStreakProvider.notifier).maybeRaise(state);
  }

  void reset() {
    state = 0;
    _save();
  }
}

final bestStreakProvider = NotifierProvider<BestStreakNotifier, int>(
  BestStreakNotifier.new,
);

class BestStreakNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.bestStreak;

  /// Raise the best-streak high-water mark if [value] beats it. No-op
  /// otherwise — best can only go up.
  void maybeRaise(int value) {
    if (value > state) {
      state = value;
      _save();
    }
  }
}

final coinProvider = NotifierProvider<CoinNotifier, int>(CoinNotifier.new);

class CoinNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.coins;

  void add(int amount) {
    state += amount;
    _save();
  }
}

/// Snapshot of step counters. [today] resets at local midnight; [lifetime]
/// keeps climbing forever. [dayKey] is the ISO date (YYYY-MM-DD) that [today]
/// belongs to — used to detect rollover on reads and writes.
class StepsState {
  final int lifetime;
  final int today;
  final String dayKey;

  const StepsState({
    required this.lifetime,
    required this.today,
    required this.dayKey,
  });

  StepsState copyWith({int? lifetime, int? today, String? dayKey}) =>
      StepsState(
        lifetime: lifetime ?? this.lifetime,
        today: today ?? this.today,
        dayKey: dayKey ?? this.dayKey,
      );
}

final stepsProvider = NotifierProvider<StepsNotifier, StepsState>(
  StepsNotifier.new,
);

class StepsNotifier extends Notifier<StepsState> {
  Box get _box => ref.read(hiveBoxProvider);
  Timer? _midnightTimer;

  @override
  StepsState build() {
    final lifetime = _box.get(HiveKeys.stepsLifetime, defaultValue: 0) as int;
    final storedDayKey =
        _box.get(HiveKeys.stepsDayKey, defaultValue: todayKey()) as String;
    final storedToday = _box.get(HiveKeys.stepsToday, defaultValue: 0) as int;
    final currentKey = todayKey();
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleMidnightRollover();
    // Stale-day detection: return rolled-over state but don't persist here.
    // Riverpod build() should be side-effect-free; the stored values stay
    // stale until the next add() or the midnight timer fires, both of
    // which persist. Build-time read is self-correcting on every session.
    if (storedDayKey != currentKey) {
      return StepsState(lifetime: lifetime, today: 0, dayKey: currentKey);
    }
    return StepsState(
      lifetime: lifetime,
      today: storedToday,
      dayKey: storedDayKey,
    );
  }

  void add(int count) {
    final currentKey = todayKey();
    final rolledOver = state.dayKey != currentKey;
    final nextToday = (rolledOver ? 0 : state.today) + count;
    final next = StepsState(
      lifetime: state.lifetime + count,
      today: nextToday,
      dayKey: currentKey,
    );
    state = next;
    _persist(next);
  }

  /// Arms a one-shot timer for local midnight so `today` resets for idle
  /// users too, not just on the next `add()`. Re-arms itself each time.
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1)
        .add(const Duration(seconds: 1));
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (state.dayKey != todayKey()) {
        final rolled = state.copyWith(today: 0, dayKey: todayKey());
        state = rolled;
        _persist(rolled);
      }
      _scheduleMidnightRollover();
    });
  }

  void _persist(StepsState s) {
    _box.put(HiveKeys.stepsLifetime, s.lifetime);
    _box.put(HiveKeys.stepsToday, s.today);
    _box.put(HiveKeys.stepsDayKey, s.dayKey);
  }
}
