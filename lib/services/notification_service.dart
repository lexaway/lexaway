import 'dart:io';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/csv_loaders.dart';
import '../data/lang_codes.dart';

/// Compute scheduled slot times for the next 7 days. Slots are evenly spread
/// within the active window with ±5min jitter so they don't all fire on the
/// hour. Past slots (earlier than [from]) are skipped.
///
/// Top-level (not a method) so tests can call it without instantiating the
/// service or its native plugin.
List<tz.TZDateTime> computeSlots({
  required tz.TZDateTime from,
  required tz.TZDateTime anchor,
  required int perDay,
  required int startHour,
  required int endHour,
  required Random random,
}) {
  final out = <tz.TZDateTime>[];
  // Window in minutes-since-midnight; wraps next day if endHour <= startHour.
  final startMin = startHour * 60;
  var endMin = endHour * 60;
  if (endMin <= startMin) endMin += 24 * 60;
  final windowMin = endMin - startMin;
  if (windowMin <= 0) return out;

  // Even spread: divide the window into perDay equal segments, take midpoint
  // of each segment.
  final step = windowMin / perDay;

  for (var day = 0; day < 7; day++) {
    // Wall-clock day arithmetic — `anchor.add(Duration(days: 1))` adds 24h
    // of absolute time, which on DST transitions lands at 1am or 11pm
    // instead of midnight, shifting every slot for that day. Constructing
    // the TZDateTime directly by incrementing the day field is DST-safe.
    final dayStart = tz.TZDateTime(
      tz.local,
      anchor.year,
      anchor.month,
      anchor.day + day,
    );
    for (var i = 0; i < perDay; i++) {
      final minute = startMin + (step * (i + 0.5)).round();
      final jitter = random.nextInt(11) - 5; // -5..+5
      final when = dayStart.add(Duration(minutes: minute + jitter));
      if (when.isAfter(from)) out.add(when);
    }
  }
  return out;
}

/// iOS hard-caps pending notifications at 64. We schedule under that to leave
/// headroom for any system-fired ones (e.g. permission rationale) — and the
/// same cap on Android keeps behavior identical across platforms.
const _maxScheduled = 60;

/// Channel + ID range used for vocab-flashcard notifications. Keeping the IDs
/// in a known band lets us `cancel(id)` individually if needed later.
const _channelId = 'vocab_flashcards';
const _channelName = 'Vocab flashcards';
const _idBase = 10000;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// One-shot init — call once after Hive opens, before runApp.
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Fall back to UTC if the platform refuses to name itself.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Don't auto-request — we ask only when the user toggles ON.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Ask the OS for permission. Returns true if granted. Safe to call more
  /// than once; the OS only prompts the first time.
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final ok = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return ok ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? true;
    }
    return false;
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Returns currently-scheduled notification count. Used in tests / debug.
  Future<int> pendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Pre-schedule up to 7 days of vocab flashcards.
  ///
  /// - [perDay]: how many per day (1–8).
  /// - [startHour]/[endHour]: active window in local time (0–23). If endHour
  ///   <= startHour the window wraps to the next day (e.g. 22 → 6).
  /// - [l2Iso3]: which L2 languages to pull from. Empty = no-op.
  /// - [l1Iso3]: the user's native language (the "source" half of the pair).
  Future<void> scheduleQueue({
    required int perDay,
    required int startHour,
    required int endHour,
    required Set<String> l2Iso3,
    required String l1Iso3,
    Random? rng,
  }) async {
    await cancelAll();
    if (perDay <= 0 || l2Iso3.isEmpty) return;

    final vocab = await loadVocab();
    if (vocab.isEmpty) return;

    // Pre-load greetings for each selected L2 once.
    final greetingsByLang = <String, List<Greeting>>{};
    for (final iso3 in l2Iso3) {
      final iso2 = iso3to2[iso3];
      if (iso2 == null) continue;
      greetingsByLang[iso3] = await loadGreetings(iso2);
    }

    final random = rng ?? Random();
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);

    final slots = computeSlots(
      from: now,
      anchor: today,
      perDay: perDay,
      startHour: startHour,
      endHour: endHour,
      random: random,
    );

    var nextId = _idBase;
    final langs = l2Iso3.toList()..sort(); // deterministic ordering
    final notifDetails = _buildDetails();

    for (final when in slots) {
      if (nextId - _idBase >= _maxScheduled) break;
      final l2 = langs[random.nextInt(langs.length)];

      final pair = _pickVocab(vocab, l1Iso3: l1Iso3, l2Iso3: l2, random: random);
      if (pair == null) continue;

      final greeting = _pickGreeting(
        greetingsByLang[l2] ?? const [],
        bucket: timeBucketForHour(when.hour),
        random: random,
      );

      // Title fallback: "Lexaway" (the app name). Using pair.l2 here would
      // make the title duplicate the L2 half of the body, which reads as
      // "maison / home → maison" — visually redundant on the lockscreen.
      final title = greeting?.text ?? 'Lexaway';
      final body = '${pair.l1} → ${pair.l2}';

      await _plugin.zonedSchedule(
        nextId++,
        title,
        body,
        when,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  NotificationDetails _buildDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'A friendly vocab flashcard now and then.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  ({String l1, String l2})? _pickVocab(
    List<VocabRow> vocab, {
    required String l1Iso3,
    required String l2Iso3,
    required Random random,
  }) {
    // Try up to 10 times to find a row with both translations non-empty.
    for (var attempt = 0; attempt < 10; attempt++) {
      final row = vocab[random.nextInt(vocab.length)];
      final l1 = row.translation(l1Iso3);
      final l2 = row.translation(l2Iso3);
      if (l1 != null && l1.isNotEmpty && l2 != null && l2.isNotEmpty) {
        return (l1: l1, l2: l2);
      }
    }
    return null;
  }

  Greeting? _pickGreeting(
    List<Greeting> all, {
    required String bucket,
    required Random random,
  }) {
    if (all.isEmpty) return null;
    final matching = all.where((g) => g.fitsTime(bucket)).toList();
    final pool = matching.isNotEmpty ? matching : all;
    return pool[random.nextInt(pool.length)];
  }
}
