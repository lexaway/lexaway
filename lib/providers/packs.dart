import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/difficulty.dart';
import '../data/pack_database.dart';
import '../data/pack_manager.dart';
import '../data/question_source.dart';
import '../data/tts_manager.dart';
import '../models/question.dart';
import 'bootstrap.dart';
import 'download_progress.dart';
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
    return ref.watch(packManagerProvider).getLocalPacks();
  }

  Future<void> download(
    String lang, {
    required String fromLang,
    required bool includeVoice,
  }) async {
    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    final packId = formatPackId(fromLang: fromLang, lang: lang);

    final packFuture =
        ref.read(downloadProgressProvider(packId).notifier).track(
      (onProgress, _) =>
          pm.downloadPack(lang, fromLang: fromLang, onProgress: onProgress),
    );

    final voiceFuture = (includeVoice && tm.isSupported(lang))
        ? ref.read(voiceDownloadProgressProvider(lang).notifier).track(
            (onProgress, onExtracting) => tm.downloadModel(
              lang,
              onProgress: onProgress,
              onExtracting: onExtracting,
            ),
          )
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

    await ref.read(voiceDownloadProgressProvider(lang).notifier).track(
      (onProgress, onExtracting) => tm.downloadModel(
        lang,
        modelId: modelId,
        onProgress: onProgress,
        onExtracting: onExtracting,
      ),
    );
    ref.invalidateSelf();
  }

  /// Delete the voice model for [lang] while leaving the sentence pack intact.
  /// Unlike [delete], which removes the voice only as a cleanup step, this
  /// honors an explicit user action and removes the model unconditionally.
  Future<void> deleteVoice(String lang) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();
    await ref.read(ttsManagerProvider).deleteModel(lang);
    ref.invalidateSelf();
  }

  Future<void> delete(String packId) async {
    // Release TTS engine before deleting files to avoid native crash
    ref.read(ttsServiceProvider).releaseEngine();

    final pm = ref.read(packManagerProvider);
    final tm = ref.read(ttsManagerProvider);
    final targetLang = parsePackId(packId).lang;

    await pm.deletePack(packId);

    // Keep the voice model if another installed pack shares the target lang.
    final remaining = pm.getLocalPacks();
    final sharedVoice = remaining.values.any((p) => p.lang == targetLang);
    if (!sharedVoice) {
      await tm.deleteModel(targetLang);
    }

    state = AsyncData(remaining);

    // Clear if we deleted the active pack. Skip if a switchPack is in flight
    // (state would be loading).
    final activeNotifier = ref.read(activePackProvider.notifier);
    if (activeNotifier.activePackId == packId && !ref.read(activePackProvider).isLoading) {
      await activeNotifier.clear();
    }
  }
}

/// Remote manifest (cached offline).
final manifestProvider = FutureProvider<Manifest>((ref) {
  return ref.watch(packManagerProvider).fetchManifest();
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

/// Ephemeral download progress for sentence packs, keyed by pack id.
final downloadProgressProvider =
    NotifierProvider.family<DownloadProgress, double?, String>(
  DownloadProgress.new,
);

/// Ephemeral download progress for voice models, keyed by lang code.
final voiceDownloadProgressProvider =
    NotifierProvider.family<DownloadProgress, double?, String>(
  DownloadProgress.new,
);

final activePackProvider =
    AsyncNotifierProvider<ActivePackNotifier, QuestionSource?>(
      ActivePackNotifier.new,
    );

/// Reactive view of [ActivePackNotifier.activeLang]. `_activePackId` only
/// changes alongside a state transition, so watching state catches every
/// change without the "watch then read notifier" dance at call sites.
final activeLangProvider = Provider<String?>((ref) {
  ref.watch(activePackProvider);
  return ref.read(activePackProvider.notifier).activeLang;
});

/// The active lang *if* TTS can speak for it — null otherwise. Non-null iff
/// there is an active lang, the engine supports it, and a voice model is
/// downloaded. Returns the lang (not a bool) so callers read once and use the
/// non-null value directly.
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

  /// Tear down a pack we can't use (corrupt DB, empty question set). Each step
  /// is guarded so one failure doesn't block the rest — we'd rather end up with
  /// stale Hive than a half-cleaned state that blocks future retries.
  Future<QuestionSource?> _discardPack(String packId) async {
    try { await _db.close(); } catch (_) {}
    try {
      await ref.read(packManagerProvider).deletePack(packId);
    } catch (_) {}
    try { ref.invalidate(localPacksProvider); } catch (_) {}
    _activePackId = null;
    return null;
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
    final ({List<Question> fresh, List<Question> review, Difficulty difficulty}) loaded;
    try {
      loaded = await _loadQuestions(packId);
    } catch (_) {
      return _discardPack(packId);
    }
    if (loaded.fresh.isEmpty && loaded.review.isEmpty) {
      return _discardPack(packId);
    }
    pm.setLastUsed(packId);
    _activePackId = packId;
    return QuestionSource(
      _db,
      loaded.fresh,
      initialReview: loaded.review,
      reviewRatio: loaded.difficulty.reviewRatio,
      difficulty: loaded.difficulty,
    );
  }

  /// Open and query the pack database. Retries once on failure — the retry
  /// re-closes and re-opens the handle, which recovers from a partially-
  /// initialized native SQLite connection (common on cold boot).
  Future<({List<Question> fresh, List<Question> review, Difficulty difficulty})>
      _loadQuestions(String packId) async {
    final difficulty = ref.read(difficultyProvider);
    for (var attempt = 0; ; attempt++) {
      try {
        await _db.open(packId);
        final fresh =
            await _db.loadQuestions(difficulty: difficulty, limit: 200);
        final review =
            await _db.loadReviewQuestions(difficulty: difficulty, limit: 50);
        return (fresh: fresh, review: review, difficulty: difficulty);
      } catch (e) {
        if (attempt > 0) rethrow;
        assert(() { debugPrint('Pack DB first attempt failed: $e'); return true; }());
        await _db.close();
      }
    }
  }
}
