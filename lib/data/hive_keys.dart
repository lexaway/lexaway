/// Centralised Hive box key constants.
///
/// Every string key used with [Box.get], [Box.put], or [Box.delete] lives here
/// so typos become compile errors instead of silent bugs.
abstract final class HiveKeys {
  // Schema
  static const hiveSchemaVersion = 'hive_schema_version';

  // Locale
  static const uiLocale = 'ui_locale';

  // Settings
  static const volMaster = 'vol_master';
  static const volSfx = 'vol_sfx';
  static const volTts = 'vol_tts';
  static const haptics = 'haptics';
  static const gender = 'gender';

  // Game stats
  static const streak = 'streak';
  static const bestStreak = 'best_streak';
  static const coins = 'coins';
  static const steps = 'steps';

  // World state
  static const world = 'world';

  // Character selection (per-language)
  static String character(String lang) => 'character_$lang';

  // Pack manager
  static const manifestCache = 'manifest_cache';
  static const packs = 'packs';
  static const lastUsed = 'last_used';

  // TTS
  static const ttsEspeakNgData = 'tts_espeak_ng_data';
  static const ttsModels = 'tts_models';
}
