import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import 'data/pack_database.dart';
import 'data/pack_manager.dart';
import 'models/question.dart';

// Bootstrap

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
});

// Pack management

/// Singleton PackManager backed by the Hive box.
final packManagerProvider = Provider<PackManager>((ref) {
  return PackManager(ref.watch(hiveBoxProvider));
});

/// Local packs on disk. Invalidate after download/delete.
final localPacksProvider =
    AsyncNotifierProvider<LocalPacksNotifier, Map<String, LocalPack>>(
        LocalPacksNotifier.new);

class LocalPacksNotifier extends AsyncNotifier<Map<String, LocalPack>> {
  @override
  Future<Map<String, LocalPack>> build() async {
    return ref.read(packManagerProvider).getLocalPacks();
  }

  Future<void> download(String lang) async {
    final pm = ref.read(packManagerProvider);
    await pm.downloadPack(lang, onProgress: (p) {
      ref.read(downloadProgressProvider(lang).notifier).state = p;
    });
    ref.read(downloadProgressProvider(lang).notifier).state = null;
    state = AsyncData(pm.getLocalPacks());
  }

  Future<void> delete(String lang) async {
    final pm = ref.read(packManagerProvider);
    await pm.deletePack(lang);
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

/// Ephemeral download progress, keyed by lang code.
final downloadProgressProvider =
    StateProvider.family<double?, String>((ref, lang) => null);

// App KV state (Hive-backed)

final streakProvider =
    NotifierProvider<StreakNotifier, int>(StreakNotifier.new);

class StreakNotifier extends Notifier<int> {
  Box get _box => ref.read(hiveBoxProvider);

  @override
  int build() => _box.get('streak', defaultValue: 0) as int;

  void increment() {
    state++;
    _box.put('streak', state);
    // Update best streak if needed
    final best = _box.get('best_streak', defaultValue: 0) as int;
    if (state > best) {
      _box.put('best_streak', state);
      ref.read(bestStreakProvider.notifier)._sync();
    }
  }

  void reset() {
    state = 0;
    _box.put('streak', 0);
  }
}

final bestStreakProvider =
    NotifierProvider<BestStreakNotifier, int>(BestStreakNotifier.new);

class BestStreakNotifier extends Notifier<int> {
  Box get _box => ref.read(hiveBoxProvider);

  @override
  int build() => _box.get('best_streak', defaultValue: 0) as int;

  void _sync() => state = _box.get('best_streak', defaultValue: 0) as int;
}

// Active pack

final activePackProvider =
    AsyncNotifierProvider<ActivePackNotifier, List<Question>>(
        ActivePackNotifier.new);

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
      // .db file missing or corrupt — scrub the stale metadata
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
