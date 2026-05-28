import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/csv_loaders.dart';
import '../data/hive_keys.dart';
import '../data/lang_codes.dart';
import '../services/notification_service.dart';
import 'bootstrap.dart';
import 'locale.dart';
import 'packs.dart';

/// User-facing knobs for the vocab-flashcard notifications.
class NotifSettings {
  final bool enabled;
  final int perDay;
  final int startHour;
  final int endHour;

  /// L2 languages (ISO 639-3) the user wants to receive flashcards in.
  final Set<String> langs;

  const NotifSettings({
    required this.enabled,
    required this.perDay,
    required this.startHour,
    required this.endHour,
    required this.langs,
  });

  NotifSettings copyWith({
    bool? enabled,
    int? perDay,
    int? startHour,
    int? endHour,
    Set<String>? langs,
  }) {
    return NotifSettings(
      enabled: enabled ?? this.enabled,
      perDay: perDay ?? this.perDay,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      langs: langs ?? this.langs,
    );
  }

  static const defaults = NotifSettings(
    enabled: false,
    perDay: 3,
    startHour: 9,
    endHour: 21,
    langs: <String>{},
  );
}

/// Singleton notification service. Init'd once from `main()` before runApp.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notifSettingsProvider =
    NotifierProvider<NotifSettingsNotifier, NotifSettings>(
  NotifSettingsNotifier.new,
);

class NotifSettingsNotifier extends Notifier<NotifSettings> {
  Box get _box => ref.read(hiveBoxProvider);

  /// Monotonic counter incremented at the start of every reschedule. An in-
  /// flight reschedule checks this after each await; if it's been bumped, a
  /// newer caller has taken over and the older one bails before issuing any
  /// `zonedSchedule` calls. Combined with the `onChangeEnd`-only slider path
  /// in the UI, this gives us "the last call wins" without explicit locking.
  int _scheduleSeq = 0;

  /// Throttle for the lifecycle-driven [refresh] path. Resume events fire on
  /// every Face ID unlock / control-center pull; rescheduling on each is
  /// wasteful and would race with itself. 30s skips the noise while still
  /// catching real returns from background.
  DateTime? _lastRefreshAt;
  static const _refreshDebounce = Duration(seconds: 30);

  @override
  NotifSettings build() {
    // Reschedule whenever the installed-packs set changes — covers pack
    // install/delete while the app is foregrounded, which otherwise would
    // only correct itself on next resume.
    ref.listen<Set<String>>(installedL2sProvider, (prev, next) {
      if (prev == null || _setEquals(prev, next)) return;
      _reschedule();
    });
    return NotifSettings(
      enabled: _box.get(HiveKeys.notifEnabled, defaultValue: false) as bool,
      perDay: _box.get(HiveKeys.notifPerDay, defaultValue: 3) as int,
      startHour: _box.get(HiveKeys.notifStartHour, defaultValue: 9) as int,
      endHour: _box.get(HiveKeys.notifEndHour, defaultValue: 21) as int,
      langs: ((_box.get(HiveKeys.notifLangs, defaultValue: <String>[]) as List)
              .cast<String>())
          .toSet(),
    );
  }

  Future<void> setEnabled(bool v) async {
    // When flipping ON, request permission first. If the user denies, leave
    // the toggle off so settings UI reflects the OS state honestly.
    if (v && !state.enabled) {
      final granted =
          await ref.read(notificationServiceProvider).requestPermission();
      if (!granted) return;
    }
    state = state.copyWith(enabled: v);
    await _box.put(HiveKeys.notifEnabled, v);
    await _reschedule();
  }

  Future<void> setPerDay(int v) async {
    final clamped = v.clamp(1, 8);
    if (clamped == state.perDay) return;
    state = state.copyWith(perDay: clamped);
    await _box.put(HiveKeys.notifPerDay, clamped);
    await _reschedule();
  }

  Future<void> setWindow({required int startHour, required int endHour}) async {
    if (startHour == state.startHour && endHour == state.endHour) return;
    state = state.copyWith(startHour: startHour, endHour: endHour);
    await _box.put(HiveKeys.notifStartHour, startHour);
    await _box.put(HiveKeys.notifEndHour, endHour);
    await _reschedule();
  }

  Future<void> toggleLang(String iso3, bool on) async {
    final next = {...state.langs};
    if (on) {
      next.add(iso3);
    } else {
      next.remove(iso3);
    }
    if (next.length == state.langs.length &&
        next.containsAll(state.langs)) {
      return;
    }
    state = state.copyWith(langs: next);
    await _box.put(HiveKeys.notifLangs, next.toList());
    await _reschedule();
  }

  /// Recompute the queue from scratch. Called by setters and from app
  /// resume. Safe to call when disabled — it just cancels any pending.
  ///
  /// The [_scheduleSeq] guard makes overlapping calls last-write-wins: every
  /// call captures the seq on entry; later checks bail if a newer call has
  /// bumped it. Without this, rapid setter calls would race on `cancelAll`
  /// vs `scheduleQueue` and leave the OS holding the older caller's queue.
  Future<void> _reschedule() async {
    final mySeq = ++_scheduleSeq;
    final svc = ref.read(notificationServiceProvider);
    if (!state.enabled || state.langs.isEmpty) {
      await svc.cancelAll();
      return;
    }
    final installed = ref.read(installedL2sProvider);
    final effective = state.langs.intersection(installed);
    if (effective.isEmpty) {
      if (mySeq != _scheduleSeq) return;
      await svc.cancelAll();
      return;
    }
    if (mySeq != _scheduleSeq) return;
    await svc.scheduleQueue(
      perDay: state.perDay,
      startHour: state.startHour,
      endHour: state.endHour,
      l2Iso3: effective,
      l1Iso3: ref.read(nativeLangProvider),
    );
    // Note: we don't recheck mySeq here. scheduleQueue starts with cancelAll,
    // so a newer caller running concurrently will have already wiped what we
    // wrote — the seq-check on the next caller's entry is sufficient.
    _lastRefreshAt = DateTime.now();
  }

  /// External callers (app start / resume) can request a refresh without
  /// changing settings. Throttled — rapid background/foreground cycles don't
  /// thrash the OS scheduler.
  Future<void> refresh() async {
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < _refreshDebounce) {
      return;
    }
    await _reschedule();
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// L2 languages (ISO 639-3) the user has installed packs for. Used to gate
/// the language picker in settings.
final installedL2sProvider = Provider<Set<String>>((ref) {
  final local = ref.watch(localPacksProvider).valueOrNull;
  if (local == null) return const {};
  return local.values.map((p) => p.lang).toSet();
});

/// A live (greeting, vocab) pair for the settings-screen preview card. Reading
/// this provider rolls a new pair; `ref.invalidate(notifPreviewProvider)` from
/// a tap handler gives the "tap to re-roll" behavior.
final notifPreviewProvider = FutureProvider<({String title, String body})?>((
  ref,
) async {
  final settings = ref.watch(notifSettingsProvider);
  final installed = ref.watch(installedL2sProvider);
  final candidates = settings.langs.intersection(installed).toList();
  if (candidates.isEmpty) return null;

  final vocab = await loadVocab();
  if (vocab.isEmpty) return null;

  final rng = Random();
  final l2 = candidates[rng.nextInt(candidates.length)];
  final iso2 = iso3to2[l2] ?? 'en';
  final greetings = await loadGreetings(iso2);

  return pickNotifContent(
    vocab: vocab,
    greetings: greetings,
    l1Iso3: ref.read(nativeLangProvider),
    l2Iso3: l2,
    bucket: timeBucketForHour(DateTime.now().hour),
    random: rng,
  );
});
