import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/app_font.dart';
import '../data/hive_keys.dart';
import 'bootstrap.dart';
import 'packs.dart';

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

final bgmVolumeProvider = NotifierProvider<BgmVolumeNotifier, double>(
  BgmVolumeNotifier.new,
);

class BgmVolumeNotifier extends HiveVolumeNotifier {
  @override
  String get key => HiveKeys.volBgm;
  @override
  double get defaultValue => 0.3;
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

// Difficulty preference

final difficultyProvider = NotifierProvider<DifficultyNotifier, String>(
  DifficultyNotifier.new,
);

class DifficultyNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(hiveBoxProvider).get(HiveKeys.difficulty, defaultValue: 'beginner')
        as String;
  }

  void set(String difficulty) {
    state = difficulty;
    ref.read(hiveBoxProvider).put(HiveKeys.difficulty, difficulty);
    ref.invalidate(activePackProvider);
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
