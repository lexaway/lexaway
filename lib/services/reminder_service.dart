import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../providers/daily_goal.dart';
import '../providers/locale.dart';
import '../providers/stats.dart';

/// Notification IDs used by Lexaway. Keep distinct so future notifications
/// don't accidentally cancel each other via a shared ID.
///   1 — daily goal reminder (single pending at a time, repeatedly
///       cancelled and rescheduled from [ReminderService.scheduleNext]).
const int _reminderNotificationId = 1;

const String _androidChannelId = 'lexaway_daily_goal';
const String _androidChannelName = 'Daily goal reminders';
const String _androidChannelDescription =
    'Gentle nudges when you haven\u2019t met today\u2019s step goal yet.';

/// Thin wrapper around flutter_local_notifications. Owns:
///   - one-time platform init (timezone + notifications plugin)
///   - on-demand permission requests
///   - computing the single next reminder datetime and scheduling it
///
/// The service is ref-driven: whenever `reminderEnabled`, `reminderTime`,
/// `dailyGoal`, or the `stepsProvider`'s goal-met status changes, we
/// recompute and reschedule.
class ReminderService {
  ReminderService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Called once during app bootstrap (from main()).
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC — scheduled times will be off by the device offset
      // on platforms where the plugin can't resolve the zone. Rare; logging
      // would be nice if we wire one up.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// Hook ref-listeners so the service reacts to settings and step changes.
  /// Call once, after [init], with the app-level ProviderContainer.
  ///
  /// [goalMetTodayProvider] already debounces step changes — it only flips
  /// when the goal-crossed status changes — so we listen to it rather than
  /// [stepsProvider] directly. A goal-amount change is also handled
  /// implicitly here because the derived bool recomputes when the goal
  /// moves, but we also listen to [dailyGoalProvider] explicitly so that
  /// changes which don't flip the met-bool (e.g. 500 → 200 while today is
  /// 50) still trigger a reschedule.
  void attachListeners() {
    _ref.listen(reminderEnabledProvider, (_, __) => scheduleNext());
    _ref.listen(reminderTimeProvider, (_, __) => scheduleNext());
    _ref.listen(dailyGoalProvider, (_, __) => scheduleNext());
    _ref.listen(goalMetTodayProvider, (_, __) => scheduleNext());
  }

  /// Request OS notification permission. Returns true if granted.
  /// Called lazily when user toggles reminders on.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return (await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Plugin returns null on Android < 13 where no permission is required.
      return (await android?.requestNotificationsPermission()) ?? true;
    }
    return true;
  }

  /// Cancel any pending reminder, then schedule the next one if conditions
  /// are met. Idempotent — safe to call on any trigger.
  Future<void> scheduleNext() async {
    await init();
    await _plugin.cancel(_reminderNotificationId);

    final enabled = _ref.read(reminderEnabledProvider);
    if (!enabled) return;

    final time = _ref.read(reminderTimeProvider);
    final goal = _ref.read(dailyGoalProvider);
    final steps = _ref.read(stepsProvider);
    final goalMetToday = steps.today >= goal;

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (goalMetToday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    const android = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();

    final l10n = await _loadLocalizations();
    await _plugin.zonedSchedule(
      _reminderNotificationId,
      l10n.reminderNotificationTitle,
      l10n.reminderNotificationBody,
      next,
      const NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<AppLocalizations> _loadLocalizations() async {
    final userLocale = _ref.read(localeProvider);
    final locale = userLocale ?? PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales
        .firstWhere(
          (l) => l.languageCode == locale.languageCode,
          orElse: () => const Locale('en'),
        );
    return AppLocalizations.delegate.load(supported);
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref);
});

/// UI-facing helper: flip the reminder toggle. If turning on, request OS
/// permission first; if denied, leave the toggle off. Returns true if the
/// final state is enabled.
///
/// We don't call `scheduleNext` / `cancel` directly here — the service's
/// `ref.listen(reminderEnabledProvider)` picks up the state change and
/// does the right thing (cancel on off, (re)schedule on on).
Future<bool> setReminderEnabled(WidgetRef ref, bool enabled) async {
  if (!enabled) {
    ref.read(reminderEnabledProvider.notifier).set(false);
    return false;
  }
  final granted = await ref.read(reminderServiceProvider).requestPermission();
  ref.read(reminderEnabledProvider.notifier).set(granted);
  return granted;
}

