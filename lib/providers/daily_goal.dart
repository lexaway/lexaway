import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_keys.dart';
import 'bootstrap.dart';
import 'stats.dart';

const int defaultDailyGoal = 200;
const String defaultReminderTime = '19:00';

enum GoalTier { quick, short, medium, long }

class DailyGoalPreset {
  final int steps;
  final int minutes;
  final GoalTier tier;
  const DailyGoalPreset({
    required this.steps,
    required this.minutes,
    required this.tier,
  });
}

/// Preset session-length buckets shown in Settings. Users think in time,
/// not raw step events; [steps] is the persisted goal and [minutes] is
/// what the tile displays.
///
/// Timing derivation (keep this honest if game constants move):
///   - `LexawayGame.walkTarget` = 256px at `walkSpeed` 80px/s → 3.2s walk
///     per correct answer.
///   - `MovementController._stepInterval` = 0.3s → ~10–11 StepTaken events
///     per walk.
///   - Read + think + 900ms advance delay → ~1.8s human overhead.
///   - Total: ~5s per correct answer, ~10 steps → ≈ 100 steps / minute.
/// If you change those constants in `lib/game/`, re-check the mapping here.
const List<DailyGoalPreset> dailyGoalPresets = [
  DailyGoalPreset(steps: 100, minutes: 1, tier: GoalTier.quick),
  DailyGoalPreset(steps: 200, minutes: 2, tier: GoalTier.short),
  DailyGoalPreset(steps: 500, minutes: 5, tier: GoalTier.medium),
  DailyGoalPreset(steps: 1000, minutes: 10, tier: GoalTier.long),
];

final dailyGoalProvider = NotifierProvider<DailyGoalNotifier, int>(
  DailyGoalNotifier.new,
);

class DailyGoalNotifier extends Notifier<int> {
  @override
  int build() {
    final box = ref.read(hiveBoxProvider);
    final stored = box.get(HiveKeys.dailyGoal, defaultValue: defaultDailyGoal)
        as int;
    final presetSteps = dailyGoalPresets.map((p) => p.steps);
    if (presetSteps.contains(stored)) return stored;
    // Stored value is no longer a preset (preset list changed between
    // versions). Snap to the nearest one and persist so the UI always
    // shows a highlighted tile.
    final snapped = presetSteps.reduce(
      (a, b) => (a - stored).abs() < (b - stored).abs() ? a : b,
    );
    box.put(HiveKeys.dailyGoal, snapped);
    return snapped;
  }

  void set(int goal) {
    state = goal;
    ref.read(hiveBoxProvider).put(HiveKeys.dailyGoal, goal);
  }
}

final reminderEnabledProvider =
    NotifierProvider<ReminderEnabledNotifier, bool>(
  ReminderEnabledNotifier.new,
);

class ReminderEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref
      .read(hiveBoxProvider)
      .get(HiveKeys.reminderEnabled, defaultValue: false) as bool;

  void set(bool enabled) {
    state = enabled;
    ref.read(hiveBoxProvider).put(HiveKeys.reminderEnabled, enabled);
  }
}

final reminderTimeProvider =
    NotifierProvider<ReminderTimeNotifier, TimeOfDay>(
  ReminderTimeNotifier.new,
);

class ReminderTimeNotifier extends Notifier<TimeOfDay> {
  @override
  TimeOfDay build() {
    final raw = ref
        .read(hiveBoxProvider)
        .get(HiveKeys.reminderTime, defaultValue: defaultReminderTime)
        as String;
    return _parse(raw);
  }

  void set(TimeOfDay time) {
    state = time;
    ref.read(hiveBoxProvider).put(HiveKeys.reminderTime, _format(time));
  }

  static TimeOfDay _parse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 19, minute: 0);
    final h = int.tryParse(parts[0]) ?? 19;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// True the moment [stepsProvider].today >= [dailyGoalProvider] for today.
/// Derived so UI code can just watch this instead of wiring both providers.
final goalMetTodayProvider = Provider<bool>((ref) {
  final steps = ref.watch(stepsProvider);
  final goal = ref.watch(dailyGoalProvider);
  return steps.today >= goal;
});
