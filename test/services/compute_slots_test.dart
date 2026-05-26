import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    // Pin to a known TZ so DST behavior is reproducible.
    tz.setLocalLocation(tz.getLocation('America/Los_Angeles'));
  });

  Random fixed() => Random(42);

  test('produces perDay * 7 slots when anchored at midnight before the window',
      () {
    final anchor = tz.TZDateTime(tz.local, 2025, 6, 1);
    final from = anchor; // window not yet started
    final slots = computeSlots(
      from: from,
      anchor: anchor,
      perDay: 3,
      startHour: 9,
      endHour: 21,
      random: fixed(),
    );
    expect(slots.length, 21);
  });

  test('all slots fall within the active window (modulo jitter)', () {
    final anchor = tz.TZDateTime(tz.local, 2025, 6, 1);
    final slots = computeSlots(
      from: anchor,
      anchor: anchor,
      perDay: 4,
      startHour: 9,
      endHour: 21,
      random: fixed(),
    );
    for (final s in slots) {
      // Window is [9:00 - jitter, 21:00 + jitter]. Jitter is ±5min; midpoint
      // math keeps slots strictly inside (start+1.5h, end-1.5h) for perDay=4.
      expect(s.hour, inInclusiveRange(8, 21));
    }
  });

  test('past slots are filtered out', () {
    final anchor = tz.TZDateTime(tz.local, 2025, 6, 1);
    // "Now" is mid-day on day 1, so all of day 1's morning slots should be
    // gone but later days remain.
    final from = tz.TZDateTime(tz.local, 2025, 6, 1, 15);
    final slots = computeSlots(
      from: from,
      anchor: anchor,
      perDay: 4,
      startHour: 9,
      endHour: 21,
      random: fixed(),
    );
    // Strictly fewer than the full 28-slot horizon — day 1 lost at least one.
    expect(slots.length, lessThan(28));
    for (final s in slots) {
      expect(s.isAfter(from), isTrue);
    }
  });

  test('wrapping window (end <= start) treats end as next-day', () {
    final anchor = tz.TZDateTime(tz.local, 2025, 6, 1);
    final slots = computeSlots(
      from: anchor,
      anchor: anchor,
      perDay: 2,
      startHour: 22,
      endHour: 6, // wraps to next-day 6am
      random: fixed(),
    );
    expect(slots.length, 14);
    // First slot should be late-evening on the anchor day.
    expect(slots.first.hour, greaterThanOrEqualTo(22));
  });

  test('DST spring-forward day keeps slots within wall-clock window', () {
    // 2025-03-09 is the US spring-forward day (2am → 3am).
    final anchor = tz.TZDateTime(tz.local, 2025, 3, 8);
    final slots = computeSlots(
      from: anchor,
      anchor: anchor,
      perDay: 2,
      startHour: 10,
      endHour: 20,
      random: Random(0), // zero jitter for stability
    );
    // Find slots on March 9 (the DST day) and assert they're still within
    // 10am–20pm wall-clock. The pre-fix code would shift them by 1h.
    final marchNineSlots =
        slots.where((s) => s.year == 2025 && s.month == 3 && s.day == 9);
    expect(marchNineSlots, isNotEmpty);
    for (final s in marchNineSlots) {
      expect(s.hour, inInclusiveRange(10, 20));
    }
  });

  test('empty window returns no slots', () {
    final anchor = tz.TZDateTime(tz.local, 2025, 6, 1);
    final slots = computeSlots(
      from: anchor,
      anchor: anchor,
      perDay: 3,
      startHour: 12,
      endHour: 12,
      random: fixed(),
    );
    // Equal hours → wraps to a full 24h window. Test the truly-empty case
    // by passing 0 perDay instead.
    expect(slots.length, 21);
    final zero = computeSlots(
      from: anchor,
      anchor: anchor,
      perDay: 0,
      startHour: 9,
      endHour: 21,
      random: fixed(),
    );
    expect(zero, isEmpty);
  });
}
