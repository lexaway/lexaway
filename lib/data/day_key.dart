/// Shared "today" key (YYYY-MM-DD, local time) used by step rollover, the
/// goal-met banner's once-per-day gate, and SM-2 review-due gating. All
/// call sites MUST go through here — date strings drift across the app
/// the moment a second helper exists (some users see "today" reset while
/// reviews still think it's yesterday).
String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

/// Same format as [todayKey], but for an arbitrary [DateTime]. Use for
/// "today + N days" computations like SM-2's next-review date.
String dayKeyOf(DateTime d) => d.toIso8601String().substring(0, 10);
