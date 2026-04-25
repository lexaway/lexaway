// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get packManagerTitle => 'Language Packs';

  @override
  String get packManagerSubtitle => 'Download a pack to start learning';

  @override
  String get retry => 'Retry';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'next →';

  @override
  String get appLanguage => 'App Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get chooseYourEgg => 'Choose your egg!';

  @override
  String get whoWillHatch => 'Who will hatch from it?';

  @override
  String get sentences => 'Sentences';

  @override
  String get voice => 'Voice';

  @override
  String get optional => 'Optional';

  @override
  String get continueLabel => 'Continue';

  @override
  String get start => 'Start';

  @override
  String get settings => 'Settings';

  @override
  String get updateApp => 'Update App';

  @override
  String get updatePack => 'Update Pack';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get communityContent =>
      'Sentences are community-contributed and may not be reviewed.';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsMaster => 'Master';

  @override
  String get settingsSfx => 'SFX';

  @override
  String get settingsMusic => 'Music';

  @override
  String get settingsGameplay => 'Gameplay';

  @override
  String get settingsHaptics => 'Haptics';

  @override
  String get settingsAutoPlayVoice => 'Auto-play voice';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsFont => 'Font';

  @override
  String get attributions => 'Attributions';

  @override
  String get extracting => 'Extracting…';

  @override
  String get settingsDifficulty => 'Difficulty';

  @override
  String get difficultyBeginner => 'Beginner';

  @override
  String get difficultyIntermediate => 'Intermediate';

  @override
  String get difficultyAdvanced => 'Advanced';

  @override
  String get settingsDailyGoal => 'Daily goal';

  @override
  String goalTimeApprox(int minutes) {
    return '~$minutes min';
  }

  @override
  String get goalTierQuick => 'Quick';

  @override
  String get goalTierShort => 'Short';

  @override
  String get goalTierMedium => 'Medium';

  @override
  String get goalTierLong => 'Long';

  @override
  String get settingsReminder => 'Reminder';

  @override
  String get settingsReminderTime => 'Remind me at';

  @override
  String get settingsReminderPermissionDenied =>
      'Notifications are blocked. Enable them in system settings.';

  @override
  String get goalMetBanner => 'Daily goal reached!';

  @override
  String get reminderNotificationTitle => 'Your dino is waiting';

  @override
  String get reminderNotificationBody =>
      'A few steps and the adventure keeps going.';
}
