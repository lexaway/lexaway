import 'dart:ui';

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

  Future<void> download(String lang) async {
    final pm = ref.read(packManagerProvider);
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
final downloadProgressProvider = StateProvider.family<double?, String>(
  (ref, lang) => null,
);

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
