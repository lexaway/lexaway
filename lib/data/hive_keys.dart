/// Centralised Hive box key constants — one place so typos are compile errors.
abstract final class HiveKeys {
  static const hiveSchemaVersion = 'hive_schema_version';

  static const uiLocale = 'ui_locale';

  static const volMaster = 'vol_master';
  static const volSfx = 'vol_sfx';
  // v2: new key so existing installs pick up the music-on-by-default era
  // instead of keeping their old (silent-by-default) saved value.
  static const volBgm = 'vol_bgm_v2';
  static const volTts = 'vol_tts';
  static const haptics = 'haptics';
  static const gender = 'gender';
  static const font = 'font';
  static const ttsAutoPlay = 'tts_auto_play';
  static const difficulty = 'difficulty';

  static const streak = 'streak';
  static const bestStreak = 'best_streak';
  static const coins = 'coins';
  static const stepsLifetime = 'steps_lifetime';
  static const stepsToday = 'steps_today';
  static const stepsDayKey = 'steps_day_key';

  static String world(String lang) => 'world_$lang';

  // Per-language lifetime steps — display-only counter for the pack tile.
  static String langSteps(String lang) => 'steps_lang_$lang';

  static String character(String lang) => 'character_$lang';

  static const manifestCache = 'manifest_cache';
  static const packs = 'packs';
  static const lastUsed = 'last_used';

  static const ttsEspeakNgData = 'tts_espeak_ng_data';
  static const ttsModels = 'tts_models';

  static const musicPacks = 'music_packs';

  static const notifEnabled = 'notif_enabled';
  static const notifPerDay = 'notif_per_day';
  static const notifStartHour = 'notif_start_hour';
  static const notifEndHour = 'notif_end_hour';
  static const notifLangs = 'notif_langs';

  // Collectibles — versioned so we can re-shape the storage later without
  // colliding with existing installs.
  static const collectibles = 'collectibles_v1';
}
