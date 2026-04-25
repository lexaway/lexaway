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
  static const volBgm = 'vol_bgm';
  static const volTts = 'vol_tts';
  static const haptics = 'haptics';
  static const gender = 'gender';
  static const font = 'font';
  static const ttsAutoPlay = 'tts_auto_play';
  static const difficulty = 'difficulty';

  // Game stats
  static const streak = 'streak';
  static const bestStreak = 'best_streak';
  static const coins = 'coins';
  static const stepsLifetime = 'steps_lifetime';
  static const stepsToday = 'steps_today';
  static const stepsDayKey = 'steps_day_key';

  // Daily goal
  static const dailyGoal = 'daily_goal';
  static const reminderEnabled = 'reminder_enabled';
  static const reminderTime = 'reminder_time';
  static const goalMetShownDayKey = 'goal_met_shown_day_key';

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
