import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pack_database.dart';
import '../data/pack_manager.dart';
import '../data/question_source.dart';
import '../data/tts_manager.dart';
import '../models/question.dart';
import 'bootstrap.dart';
import 'settings.dart';
import 'tts.dart';

/// Schema version bounds for local pack compatibility.
/// Overridable in tests so the gate can be exercised without mutating globals.
final packSchemaBoundsProvider = Provider<({int min, int max})>((ref) {
  return (min: minSupportedPackSchema, max: maxSupportedPackSchema);
});

/// Singleton PackManager backed by the Hive box.
final packManagerProvider = Provider<PackManager>((ref) {
  return PackManager(ref.watch(hiveBoxProvider), packsDir: ref.watch(packsDirProvider));
});

/// Local packs on disk. Mutations go through the notifier, which owns its
/// own state updates — callers don't need to invalidate afterwards.
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
    final packId = formatPackId(fromLang: fromLang, lang: lang);

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

    final voiceFuture = (includeVoice && tm.isSupported(lang))
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
    if (!tm.isSupported(lang)) return;

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

  /// Delete the voice model for [lang] while leaving the sentence pack intact.
  /// Unlike [delete], which removes the voice only as a cleanup step, this
  /// honors an explicit user action and removes the model unconditionally.
  Future<void> deleteVoice(String lang) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();
    await ref.read(ttsManagerProvider).deleteModel(lang);
    // Trigger rebuild so the UI picks up the removed voice state.
    ref.invalidateSelf();
  }

  Future<void> delete(String packId) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();

    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    final targetLang = parsePackId(packId).lang;

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

/// Live TTS voice catalog: bundled baseline overlaid with `Manifest.voices`.
/// Manifest entries override per-lang (presence wins, even an empty list —
/// that means "this lang has no voices"). Falls back to baseline alone while
/// the manifest is loading or errored, so the UI is always populated.
///
/// Pure derivation. The push into [TtsManager.voiceCatalog] (so non-Riverpod
/// playback paths see the same view) is wired separately in `LexawayApp` via
/// `ref.listenManual`.
final voiceCatalogProvider = Provider<Map<String, List<TtsModelInfo>>>((ref) {
  final manifest = ref.watch(manifestProvider);
  final merged = <String, List<TtsModelInfo>>{...kBaselineVoiceCatalog};
  manifest.whenData((m) {
    merged.addAll(m.voices);
  });
  return merged;
});

/// Ephemeral download progress for sentence packs, keyed by lang code.
final downloadProgressProvider = StateProvider.family<double?, String>(
  (ref, lang) => null,
);

/// Ephemeral download progress for voice models, keyed by lang code.
final voiceDownloadProgressProvider = StateProvider.family<double?, String>(
  (ref, lang) => null,
);

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

/// The active lang *if* TTS can speak for it — null otherwise. Non-null iff
///   1. there is an active lang, AND
///   2. the engine supports it, AND
///   3. a voice model has been downloaded for it.
///
/// Rebuilds when the active lang changes or when a voice model is added /
/// removed (both of which flow through [localPacksProvider]).
///
/// Returning the lang instead of a bool lets callers do a single read and
/// use the non-null value directly, avoiding a second `activeLangProvider`
/// read plus a bang-assertion at each call site.
final activeTtsLangProvider = Provider<String?>((ref) {
  final lang = ref.watch(activeLangProvider);
  if (lang == null || !ref.read(ttsManagerProvider).isSupported(lang)) return null;
  // Watched for its invalidation signal — voice downloads/deletes rebuild it,
  // which is how we learn that `isModelDownloaded` may now return differently.
  ref.watch(localPacksProvider);
  if (!ref.read(ttsManagerProvider).isModelDownloaded(lang)) return null;
  return lang;
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
  String? get activeLang {
    final id = _activePackId;
    return id == null ? null : parsePackId(id).lang;
  }

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
    final ({List<Question> fresh, List<Question> review, String difficulty}) loaded;
    try {
      loaded = await _loadQuestions(packId);
    } catch (_) {
      // .db file missing or corrupt — close leaked handle, scrub stale metadata.
      // Protect each step so one failure doesn't block the rest.
      await _db.close();
      try { await pm.deletePack(packId); } catch (_) {}
      try { ref.invalidate(localPacksProvider); } catch (_) {}
      _activePackId = null;
      return null;
    }
    if (loaded.fresh.isEmpty && loaded.review.isEmpty) {
      try { await _db.close(); } catch (_) {}
      try { await pm.deletePack(packId); } catch (_) {}
      try { ref.invalidate(localPacksProvider); } catch (_) {}
      _activePackId = null;
      return null;
    }
    pm.setLastUsed(packId);
    _activePackId = packId;
    return QuestionSource(
      _db,
      loaded.fresh,
      initialReview: loaded.review,
      reviewRatio: _reviewRatio(loaded.difficulty),
      difficulty: loaded.difficulty,
    );
  }

  /// Map difficulty to review ratio — beginners see more review to reinforce
  /// basics; advanced players see less repetition.
  static double _reviewRatio(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return 0.33;
      case 'intermediate':
        return 0.25;
      default:
        return 0.15;
    }
  }

  /// Open and query the pack database. Retries once on failure — the retry
  /// re-closes and re-opens the handle, which recovers from a partially-
  /// initialized native SQLite connection (common on cold boot).
  Future<({List<Question> fresh, List<Question> review, String difficulty})>
      _loadQuestions(String packId) async {
    final difficulty = ref.read(difficultyProvider);
    try {
      await _db.open(packId);
      final fresh =
          await _db.loadQuestions(difficulty: difficulty, limit: 200);
      final review =
          await _db.loadReviewQuestions(difficulty: difficulty, limit: 50);
      return (fresh: fresh, review: review, difficulty: difficulty);
    } catch (e) {
      assert(() { debugPrint('Pack DB first attempt failed: $e'); return true; }());
      await _db.close();
      await _db.open(packId);
      final fresh =
          await _db.loadQuestions(difficulty: difficulty, limit: 200);
      final review =
          await _db.loadReviewQuestions(difficulty: difficulty, limit: 50);
      return (fresh: fresh, review: review, difficulty: difficulty);
    }
  }
}
