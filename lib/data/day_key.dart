/// Shared "today" key format used by step rollover, migration, and the
/// goal-met banner's once-per-day gate. Must be kept consistent across all
/// call sites — duplicate definitions will drift.
String todayKey() => DateTime.now().toIso8601String().substring(0, 10);
