import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import 'data/pack_database.dart';
import 'data/pack_manager.dart';
import 'data/tts_manager.dart';
import 'data/tts_service.dart';
import 'models/question.dart';

// Bootstrap

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
});

// Locale

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final tag = ref.read(hiveBoxProvider).get('ui_locale') as String?;
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
      box.put('ui_locale', locale.toLanguageTag());
    } else {
      box.delete('ui_locale');
    }
  }
}

// Settings

final masterVolumeProvider = NotifierProvider<MasterVolumeNotifier, double>(
  MasterVolumeNotifier.new,
);

class MasterVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get('vol_master', defaultValue: 1.0)
        as num).toDouble();
  }

  /// Update in-memory state (call on every drag tick for responsive UI).
  void set(double v) => state = v.clamp(0.0, 1.0);

  /// Persist to Hive (call on drag end).
  void save() => ref.read(hiveBoxProvider).put('vol_master', state);
}

final sfxVolumeProvider = NotifierProvider<SfxVolumeNotifier, double>(
  SfxVolumeNotifier.new,
);

class SfxVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get('vol_sfx', defaultValue: 1.0)
        as num).toDouble();
  }

  void set(double v) => state = v.clamp(0.0, 1.0);

  void save() => ref.read(hiveBoxProvider).put('vol_sfx', state);
}

final ttsVolumeProvider = NotifierProvider<TtsVolumeNotifier, double>(
  TtsVolumeNotifier.new,
);

class TtsVolumeNotifier extends Notifier<double> {
  @override
  double build() {
    return (ref.read(hiveBoxProvider).get('vol_tts', defaultValue: 1.0)
        as num).toDouble();
  }

  void set(double v) => state = v.clamp(0.0, 1.0);

  void save() => ref.read(hiveBoxProvider).put('vol_tts', state);
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabledNotifier, bool>(
      HapticsEnabledNotifier.new,
    );

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(hiveBoxProvider).get('haptics', defaultValue: true)
        as bool;
  }

  void set(bool v) {
    state = v;
    ref.read(hiveBoxProvider).put('haptics', v);
  }
}

// Gender preference

final genderProvider = NotifierProvider<GenderNotifier, String>(
  GenderNotifier.new,
);

class GenderNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(hiveBoxProvider).get('gender', defaultValue: 'female')
        as String;
  }

  void set(String gender) {
    state = gender;
    ref.read(hiveBoxProvider).put('gender', gender);
  }
}

// Pack management

/// Singleton PackManager backed by the Hive box.
final packManagerProvider = Provider<PackManager>((ref) {
  return PackManager(ref.watch(hiveBoxProvider));
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

  Future<void> download(String lang, {required bool includeVoice}) async {
    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);

    final packFuture = () async {
      try {
        await pm.downloadPack(
          lang,
          onProgress: (p) {
            ref.read(downloadProgressProvider(lang).notifier).state = p;
          },
        );
      } finally {
        ref.read(downloadProgressProvider(lang).notifier).state = null;
      }
    }();

    final voiceFuture = (includeVoice && TtsManager.isSupported(lang))
        ? () async {
            try {
              await tm.downloadModel(
                lang,
                onProgress: (p) {
                  ref.read(voiceDownloadProgressProvider(lang).notifier).state =
                      p;
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

  /// Download just the voice model for an already-installed pack.
  Future<void> downloadVoice(String lang) async {
    final tm = ref.read(ttsManagerProvider);
    if (!TtsManager.isSupported(lang) || tm.isModelDownloaded(lang)) return;

    try {
      await tm.downloadModel(
        lang,
        onProgress: (p) {
          ref.read(voiceDownloadProgressProvider(lang).notifier).state = p;
        },
      );
    } finally {
      ref.read(voiceDownloadProgressProvider(lang).notifier).state = null;
    }
    // Trigger rebuild so the UI picks up the new voice state
    ref.invalidateSelf();
  }

  Future<void> delete(String lang) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();

    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    await pm.deletePack(lang);
    await tm.deleteModel(lang);
    state = AsyncData(pm.getLocalPacks());

    // If we just deleted the active pack, kick back to pack selection
    final activeLang = ref.read(activePackProvider.notifier).activeLang;
    if (activeLang == lang) {
      ref.invalidate(activePackProvider);
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
  return TtsManager(ref.watch(hiveBoxProvider));
});

/// Singleton TtsService — lazily initialises per language.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
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
  String get key => 'streak';

  void increment() {
    state++;
    _save();
    final best = _box.get('best_streak', defaultValue: 0) as int;
    if (state > best) {
      _box.put('best_streak', state);
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
  String get key => 'best_streak';

  void _sync() => state = _box.get(key, defaultValue: defaultValue) as int;
}

final coinProvider = NotifierProvider<CoinNotifier, int>(CoinNotifier.new);

class CoinNotifier extends HiveIntNotifier {
  @override
  String get key => 'coins';

  void add(int amount) {
    state += amount;
    _save();
  }
}

final stepsProvider = NotifierProvider<StepsNotifier, int>(StepsNotifier.new);

class StepsNotifier extends HiveIntNotifier {
  @override
  String get key => 'steps';

  void add(int count) {
    state += count;
    _save();
  }
}

// Active pack

final activePackProvider =
    AsyncNotifierProvider<ActivePackNotifier, List<Question>>(
      ActivePackNotifier.new,
    );

class ActivePackNotifier extends AsyncNotifier<List<Question>> {
  final _db = PackDatabase();
  String? _activeLang;

  @override
  Future<List<Question>> build() async {
    ref.onDispose(() => _db.close());

    final pm = ref.read(packManagerProvider);
    final local = pm.getLocalPacks();
    if (local.isEmpty) return [];

    final lang = pm.lastUsed ?? local.keys.first;
    return _openAndLoad(lang);
  }

  String? get activeLang => _activeLang;

  Future<void> switchPack(String lang) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _openAndLoad(lang));
  }

  Future<List<Question>> _openAndLoad(String lang) async {
    try {
      await _db.open(lang);
    } catch (_) {
      // .db file missing or corrupt — close leaked handle, scrub stale metadata
      await _db.close();
      final pm = ref.read(packManagerProvider);
      await pm.deletePack(lang);
      ref.invalidate(localPacksProvider);
      _activeLang = null;
      return [];
    }
    final qs = await _db.loadQuestions(limit: 200);
    if (qs.isEmpty) {
      await _db.close();
      final pm = ref.read(packManagerProvider);
      await pm.deletePack(lang);
      ref.invalidate(localPacksProvider);
      _activeLang = null;
      return [];
    }
    ref.read(packManagerProvider).setLastUsed(lang);
    _activeLang = lang;
    return qs;
  }
}
