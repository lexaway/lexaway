import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import 'data/hive_keys.dart';
import 'data/pack_database.dart';
import 'data/pack_manager.dart';
import 'data/question_source.dart';
import 'data/tts_manager.dart';
import 'data/tts_service.dart';

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

final masterVolumeProvider = NotifierProvider<MasterVolumeNotifier, double>(
  MasterVolumeNotifier.new,
);

class MasterVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get(HiveKeys.volMaster, defaultValue: 1.0)
        as num).toDouble();
  }

  /// Update in-memory state (call on every drag tick for responsive UI).
  void set(double v) => state = v.clamp(0.0, 1.0);

  /// Persist to Hive (call on drag end).
  void save() => ref.read(hiveBoxProvider).put(HiveKeys.volMaster, state);
}

final sfxVolumeProvider = NotifierProvider<SfxVolumeNotifier, double>(
  SfxVolumeNotifier.new,
);

class SfxVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get(HiveKeys.volSfx, defaultValue: 1.0)
        as num).toDouble();
  }

  void set(double v) => state = v.clamp(0.0, 1.0);

  void save() => ref.read(hiveBoxProvider).put(HiveKeys.volSfx, state);
}

final ttsVolumeProvider = NotifierProvider<TtsVolumeNotifier, double>(
  TtsVolumeNotifier.new,
);

class TtsVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get(HiveKeys.volTts, defaultValue: 1.0)
        as num).toDouble();
  }

  void set(double v) => state = v.clamp(0.0, 1.0);

  void save() => ref.read(hiveBoxProvider).put(HiveKeys.volTts, state);
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

// Pack management

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

/// Whether to include voice in the next download, keyed by lang code.
/// Defaults to true.
final includeVoiceProvider = StateProvider.family<bool, String>(
  (ref, lang) => true,
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

    final packId = pm.lastUsed ?? local.keys.first;
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
    try {
      await _db.open(packId);
    } catch (_) {
      // .db file missing or corrupt — close leaked handle, scrub stale metadata
      await _db.close();
      final pm = ref.read(packManagerProvider);
      await pm.deletePack(packId);
      ref.invalidate(localPacksProvider);
      _activePackId = null;
      return null;
    }
    final qs = await _db.loadQuestions(limit: 200);
    if (qs.isEmpty) {
      await _db.close();
      final pm = ref.read(packManagerProvider);
      await pm.deletePack(packId);
      ref.invalidate(localPacksProvider);
      _activePackId = null;
      return null;
    }
    ref.read(packManagerProvider).setLastUsed(packId);
    _activePackId = packId;
    return QuestionSource(_db, qs);
  }
}
