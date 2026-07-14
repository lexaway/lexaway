/// Shared "today" key (YYYY-MM-DD, local time) for step rollover and SM-2
/// review gating. All call sites MUST go through here — a second helper lets
/// date strings drift (step "today" resets while reviews think it's yesterday).
String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

/// Like [todayKey] for an arbitrary [DateTime] — e.g. SM-2's next-review date.
String dayKeyOf(DateTime d) => d.toIso8601String().substring(0, 10);
