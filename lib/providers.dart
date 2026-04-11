import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import 'data/app_font.dart';
import 'data/hive_keys.dart';
import 'data/pack_database.dart';
import 'data/pack_manager.dart';
import 'data/question_source.dart';
import 'data/tts_cache.dart';
import 'data/tts_manager.dart';
import 'data/tts_service.dart';
import 'models/question.dart';

// Bootstrap

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
});

/// Pre-resolved directory paths, overridden in ProviderScope.
final packsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('packsDirProvider must be overridden');
});
final modelsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('modelsDirProvider must be overridden');
});
final tmpDirProvider = Provider<String>((ref) {
  throw UnimplementedError('tmpDirProvider must be overridden');
});

// Locale

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final tag = ref.read(hiveBoxProvider).get(HiveKeys.uiLocale) as String?;
    if (tag == null) return null;
    final parts = tag.split('-');
    return switch (parts.length) {
      1 => Locale(parts[0]),
      2 => Locale(parts[0], parts[1]),
      _ => Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts.length > 2 ? parts[1] : null,
        countryCode: parts.last,
      ),
    };
  }

  void setLocale(Locale? locale) {
    state = locale;
    final box = ref.read(hiveBoxProvider);
    if (locale != null) {
      box.put(HiveKeys.uiLocale, locale.toLanguageTag());
    } else {
      box.delete(HiveKeys.uiLocale);
    }
  }
}

// Native language (ISO 639-3, derived from locale)

final nativeLangProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  final code = locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return iso2to3[code] ?? 'eng';
});

// Settings

/// Base class for Hive-backed volume sliders (0.0..1.0).
/// Splits `set` (drag tick) from `save` (drag end) for responsive UI.
abstract class HiveVolumeNotifier extends Notifier<double> {
  String get key;
  double get defaultValue => 1.0;

  Box get _box => ref.read(hiveBoxProvider);

  @override
  double build() =>
      (_box.get(key, defaultValue: defaultValue) as num).toDouble();

  /// Update in-memory state (call on every drag tick for responsive UI).
  void set(double v) => state = v.clamp(0.0, 1.0);

  /// Persist to Hive (call on drag end).
  void save() => _box.put(key, state);
}

final masterVolumeProvider = NotifierProvider<MasterVolumeNotifier, double>(
  MasterVolumeNotifier.new,
);

class MasterVolumeNotifier extends HiveVolumeNotifier {
  @override
  String get key => HiveKeys.volMaster;
}

final sfxVolumeProvider = NotifierProvider<SfxVolumeNotifier, double>(
  SfxVolumeNotifier.new,
);

class SfxVolumeNotifier extends HiveVolumeNotifier {
  @override
  String get key => HiveKeys.volSfx;
  @override
  double get defaultValue => 0.5;
}

final ttsVolumeProvider = NotifierProvider<TtsVolumeNotifier, double>(
  TtsVolumeNotifier.new,
);

class TtsVolumeNotifier extends HiveVolumeNotifier {
  @override
  String get key => HiveKeys.volTts;
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabledNotifier, bool>(
      HapticsEnabledNotifier.new,
    );

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(hiveBoxProvider).get(HiveKeys.haptics, defaultValue: true)
        as bool;
  }

  void set(bool v) {
    state = v;
    ref.read(hiveBoxProvider).put(HiveKeys.haptics, v);
  }
}

final autoPlayTtsProvider =
    NotifierProvider<AutoPlayTtsNotifier, bool>(AutoPlayTtsNotifier.new);

class AutoPlayTtsNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(hiveBoxProvider).get(HiveKeys.ttsAutoPlay, defaultValue: true)
        as bool;
  }

  void set(bool v) {
    state = v;
    ref.read(hiveBoxProvider).put(HiveKeys.ttsAutoPlay, v);
  }
}

// Gender preference

final genderProvider = NotifierProvider<GenderNotifier, String>(
  GenderNotifier.new,
);

class GenderNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(hiveBoxProvider).get(HiveKeys.gender, defaultValue: 'female')
        as String;
  }

  void set(String gender) {
    state = gender;
    ref.read(hiveBoxProvider).put(HiveKeys.gender, gender);
  }
}

// Font preference

final fontProvider = NotifierProvider<FontNotifier, AppFont>(FontNotifier.new);

class FontNotifier extends Notifier<AppFont> {
  @override
  AppFont build() {
    final key = ref.read(hiveBoxProvider).get(HiveKeys.font) as String?;
    return AppFont.fromKey(key);
  }

  void set(AppFont font) {
    state = font;
    ref.read(hiveBoxProvider).put(HiveKeys.font, font.name);
  }
}

// Character selection (per-language)

/// Selected character key (e.g. "female/doux") for a given target language,
/// or null if the user hasn't hatched an egg for that language yet.
final characterProvider =
    NotifierProvider.family<CharacterNotifier, String?, String>(
      CharacterNotifier.new,
    );

class CharacterNotifier extends FamilyNotifier<String?, String> {
  @override
  String? build(String lang) {
    return ref.read(hiveBoxProvider).get(HiveKeys.character(lang)) as String?;
  }

  void set(String characterKey) {
    state = characterKey;
    ref.read(hiveBoxProvider).put(HiveKeys.character(arg), characterKey);
  }
}

// Pack management

/// Schema version bounds for local pack compatibility.
/// Overridable in tests so the gate can be exercised without mutating globals.
final packSchemaBoundsProvider = Provider<({int min, int max})>((ref) {
  return (min: minSupportedPackSchema, max: maxSupportedPackSchema);
});

/// Singleton PackManager backed by the Hive box.
final packManagerProvider = Provider<PackManager>((ref) {
  return PackManager(ref.watch(hiveBoxProvider), packsDir: ref.watch(packsDirProvider));
});

/// Local packs on disk. Invalidate after download/delete.
final localPacksProvider =
    AsyncNotifierProvider<LocalPacksNotifier, Map<String, LocalPack>>(
      LocalPacksNotifier.new,
    );

class LocalPacksNotifier extends AsyncNotifier<Map<String, LocalPack>> {
  @override
  Future<Map<String, LocalPack>> build() async {
    return ref.read(packManagerProvider).getLocalPacks();
  }

  Future<void> download(
    String lang, {
    required String fromLang,
    required bool includeVoice,
  }) async {
    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    final packId = '$fromLang-$lang';

    final packFuture = () async {
      ref.read(downloadProgressProvider(packId).notifier).state = 0.0;
      try {
        await pm.downloadPack(
          lang,
          fromLang: fromLang,
          onProgress: (p) {
            ref.read(downloadProgressProvider(packId).notifier).state = p;
          },
        );
      } finally {
        ref.read(downloadProgressProvider(packId).notifier).state = null;
      }
    }();

    final voiceFuture = (includeVoice && TtsManager.isSupported(lang))
        ? () async {
            ref.read(voiceDownloadProgressProvider(lang).notifier).state = 0.0;
            try {
              await tm.downloadModel(
                lang,
                onProgress: (p) {
                  ref.read(voiceDownloadProgressProvider(lang).notifier).state =
                      p;
                },
                onExtracting: () {
                  ref.read(voiceDownloadProgressProvider(lang).notifier).state =
                      -1.0;
                },
              );
            } finally {
              ref.read(voiceDownloadProgressProvider(lang).notifier).state =
                  null;
            }
          }()
        : Future<void>.value();

    await Future.wait([packFuture, voiceFuture]);
    state = AsyncData(pm.getLocalPacks());
  }

  /// Download a voice model for an already-installed pack.
  /// If [modelId] is null, downloads the default model for the language.
  Future<void> downloadVoice(String lang, {String? modelId}) async {
    final tm = ref.read(ttsManagerProvider);
    if (!TtsManager.isSupported(lang)) return;

    // Release engine before replacing — avoids native crash if model files change
    ref.read(ttsServiceProvider).releaseEngine();

    // Show indeterminate spinner immediately (covers URL resolution delay)
    ref.read(voiceDownloadProgressProvider(lang).notifier).state = 0.0;
    try {
      await tm.downloadModel(
        lang,
        modelId: modelId,
        onProgress: (p) {
          ref.read(voiceDownloadProgressProvider(lang).notifier).state = p;
        },
        onExtracting: () {
          ref.read(voiceDownloadProgressProvider(lang).notifier).state = -1.0;
        },
      );
    } finally {
      ref.read(voiceDownloadProgressProvider(lang).notifier).state = null;
    }
    // Trigger rebuild so the UI picks up the new voice state
    ref.invalidateSelf();
  }

  Future<void> delete(String packId) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();

    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    final targetLang = packId.split('-')[1];

    await pm.deletePack(packId);

    // Only delete voice model if no other installed pack shares the target language.
    final remaining = pm.getLocalPacks();
    final sharedVoice = remaining.values.any((p) => p.lang == targetLang);
    if (!sharedVoice) {
      await tm.deleteModel(targetLang);
    }

    state = AsyncData(remaining);

    // If we just deleted the active pack, clear it.
    // Skip if a switchPack is already in flight (state would be loading).
    final activeNotifier = ref.read(activePackProvider.notifier);
    if (activeNotifier.activePackId == packId && !ref.read(activePackProvider).isLoading) {
      await activeNotifier.clear();
    }
  }
}

/// Remote manifest (cached offline).
final manifestProvider = FutureProvider<Manifest>((ref) {
  return ref.read(packManagerProvider).fetchManifest();
});

/// Ephemeral download progress for sentence packs, keyed by lang code.
final downloadProgressProvider = StateProvider.family<double?, String>(
  (ref, lang) => null,
);

/// Ephemeral download progress for voice models, keyed by lang code.
final voiceDownloadProgressProvider = StateProvider.family<double?, String>(
  (ref, lang) => null,
);

// TTS

/// Singleton TtsManager backed by the Hive box.
final ttsManagerProvider = Provider<TtsManager>((ref) {
  return TtsManager(ref.watch(hiveBoxProvider), modelsDir: ref.watch(modelsDirProvider));
});

/// Singleton TtsService — lazily initialises per language.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService(tmpDir: ref.watch(tmpDirProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

/// Singleton TtsCache — manages prefetch queue and in-memory audio cache.
final ttsCacheProvider = Provider<TtsCache>((ref) {
  return TtsCache(
    ttsService: ref.watch(ttsServiceProvider),
    ttsManager: ref.watch(ttsManagerProvider),
  );
});

// App KV state (Hive-backed)

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
    final best = _box.get(HiveKeys.bestStreak, defaultValue: 0) as int;
    if (state > best) {
      _box.put(HiveKeys.bestStreak, state);
      ref.read(bestStreakProvider.notifier)._sync();
    }
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

  void _sync() => state = _box.get(key, defaultValue: defaultValue) as int;
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

final stepsProvider = NotifierProvider<StepsNotifier, int>(StepsNotifier.new);

class StepsNotifier extends HiveIntNotifier {
  @override
  String get key => HiveKeys.steps;

  void add(int count) {
    state += count;
    _save();
  }
}

// Active pack

final activePackProvider =
    AsyncNotifierProvider<ActivePackNotifier, QuestionSource?>(
      ActivePackNotifier.new,
    );

/// Reactive view of [ActivePackNotifier.activeLang]. The lang lives on the
/// notifier (derived from `_activePackId`), but `_activePackId` only ever
/// changes alongside a state transition — so watching the state reliably
/// catches every change without exposing the "watch then read notifier"
/// dance at call sites.
final activeLangProvider = Provider<String?>((ref) {
  ref.watch(activePackProvider);
  return ref.read(activePackProvider.notifier).activeLang;
});

class ActivePackNotifier extends AsyncNotifier<QuestionSource?> {
  late final PackDatabase _db;
  String? _activePackId;

  @override
  Future<QuestionSource?> build() async {
    final db = PackDatabase(packsDir: ref.read(packsDirProvider));
    _db = db;
    ref.onDispose(() => db.close());

    final pm = ref.read(packManagerProvider);
    final local = pm.getLocalPacks();
    if (local.isEmpty) return null;

    // Filter to schema-compatible packs so a stale `lastUsed` doesn't
    // strand a multi-pack user on /packs when they have other valid packs.
    final bounds = ref.read(packSchemaBoundsProvider);
    final schemaOk = local.entries
        .where((e) =>
            localPackStatus(e.value, min: bounds.min, max: bounds.max) !=
            PackUpdateStatus.localOutdated)
        .map((e) => e.key)
        .toSet();
    if (schemaOk.isEmpty) return null;

    final lastUsed = pm.lastUsed;
    final packId = (lastUsed != null && schemaOk.contains(lastUsed))
        ? lastUsed
        : schemaOk.first;
    return _openAndLoad(packId);
  }

  /// The composite pack ID (e.g. "eng-fra").
  String? get activePackId => _activePackId;

  /// The target language code (e.g. "fra"), derived from the active pack ID.
  String? get activeLang => _activePackId?.split('-')[1];

  /// Clear without rebuilding — avoids the router redirect dance.
  Future<void> clear() async {
    try {
      await _db.close();
    } catch (_) {
      // DB may never have been opened (e.g. no packs installed).
    }
    _activePackId = null;
    state = const AsyncData(null);
  }

  Future<void> switchPack(String packId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _openAndLoad(packId));
  }

  Future<QuestionSource?> _openAndLoad(String packId) async {
    // Non-destructive schema gate: if the local pack is outside the supported
    // schema window, bail out *before* touching SQLite. Returning null mimics
    // the fresh-install path in `build()`; the router then redirects to /packs
    // where the user can re-download via the existing update affordance.
    // Critically, we do NOT deletePack or setLastUsed here — offline users
    // keep their file until the atomic re-download succeeds.
    final pm = ref.read(packManagerProvider);
    final localPack = pm.getLocalPacks()[packId];
    final bounds = ref.read(packSchemaBoundsProvider);
    if (localPackStatus(localPack, min: bounds.min, max: bounds.max) ==
        PackUpdateStatus.localOutdated) {
      _activePackId = null;
      return null;
    }

    // SqliteDatabase(path:) is lazy — `open` doesn't actually touch disk, so
    // genuine corruption (truncated file, malformed sqlite, bad phrases table)
    // usually surfaces on the first real query. Both paths share the same
    // cleanup: close the handle, scrub Hive, redirect to /packs.
    final List<Question> qs;
    try {
      await _db.open(packId);
      qs = await _db.loadQuestions(limit: 200);
    } catch (_) {
      // .db file missing or corrupt — close leaked handle, scrub stale metadata
      await _db.close();
      await pm.deletePack(packId);
      ref.invalidate(localPacksProvider);
      _activePackId = null;
      return null;
    }
    if (qs.isEmpty) {
      await _db.close();
      await pm.deletePack(packId);
      ref.invalidate(localPacksProvider);
      _activePackId = null;
      return null;
    }
    pm.setLastUsed(packId);
    _activePackId = packId;
    return QuestionSource(_db, qs);
  }
}
