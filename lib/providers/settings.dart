import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/app_font.dart';
import '../data/hive_keys.dart';
import 'bootstrap.dart';
import 'packs.dart';

/// Hive-backed volume slider (0.0..1.0). Splits [set] (drag tick) from [save]
/// (drag end) so the UI stays responsive without writing on every frame.
abstract class HiveVolumeNotifier extends Notifier<double> {
  String get key;
  double get defaultValue => 1.0;

  Box get _box => ref.read(hiveBoxProvider);

  @override
  double build() =>
      (_box.get(key, defaultValue: defaultValue) as num).toDouble();

  void set(double v) => state = v.clamp(0.0, 1.0);

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
  double get defaultValue => 0.5;
}

final ttsVolumeProvider = NotifierProvider<TtsVolumeNotifier, double>(
  TtsVolumeNotifier.new,
);

class TtsVolumeNotifier extends HiveVolumeNotifier {
  @override
  String get key => HiveKeys.volTts;
}

/// Hive-backed scalar setting. Override [encode]/[decode] for non-primitive
/// types (see [FontNotifier]); override [onSet] for cross-provider side-effects
/// (see [DifficultyNotifier]).
abstract class HiveValueNotifier<T> extends Notifier<T> {
  String get key;
  T get defaultValue;

  Object? encode(T v) => v;
  T decode(Object raw) => raw as T;
  void onSet(T v) {}

  Box get _box => ref.read(hiveBoxProvider);

  @override
  T build() {
    final raw = _box.get(key);
    return raw == null ? defaultValue : decode(raw);
  }

  void set(T v) {
    state = v;
    _box.put(key, encode(v));
    onSet(v);
  }
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabledNotifier, bool>(
      HapticsEnabledNotifier.new,
    );

class HapticsEnabledNotifier extends HiveValueNotifier<bool> {
  @override
  String get key => HiveKeys.haptics;
  @override
  bool get defaultValue => true;
}

final autoPlayTtsProvider =
    NotifierProvider<AutoPlayTtsNotifier, bool>(AutoPlayTtsNotifier.new);

class AutoPlayTtsNotifier extends HiveValueNotifier<bool> {
  @override
  String get key => HiveKeys.ttsAutoPlay;
  @override
  bool get defaultValue => true;
}

final genderProvider = NotifierProvider<GenderNotifier, String>(
  GenderNotifier.new,
);

class GenderNotifier extends HiveValueNotifier<String> {
  @override
  String get key => HiveKeys.gender;
  @override
  String get defaultValue => 'female';
}

final difficultyProvider = NotifierProvider<DifficultyNotifier, String>(
  DifficultyNotifier.new,
);

class DifficultyNotifier extends HiveValueNotifier<String> {
  @override
  String get key => HiveKeys.difficulty;
  @override
  String get defaultValue => 'beginner';
  @override
  void onSet(String _) => ref.invalidate(activePackProvider);
}

final fontProvider = NotifierProvider<FontNotifier, AppFont>(FontNotifier.new);

class FontNotifier extends HiveValueNotifier<AppFont> {
  @override
  String get key => HiveKeys.font;
  @override
  AppFont get defaultValue => AppFont.fromKey(null);
  @override
  Object encode(AppFont v) => v.name;
  @override
  AppFont decode(Object raw) => AppFont.fromKey(raw as String);
}
