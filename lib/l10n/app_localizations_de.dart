// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get packManagerTitle => 'Sprachpakete';

  @override
  String get packManagerSubtitle => 'Lade ein Paket herunter, um loszulegen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String downloadFailed(String error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'weiter →';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get chooseYourEgg => 'Wähle dein Ei!';

  @override
  String get whoWillHatch => 'Wer wird schlüpfen?';

  @override
  String get sentences => 'Sätze';

  @override
  String get voice => 'Stimme';

  @override
  String get optional => 'Optional';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get start => 'Starten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get updateApp => 'App aktualisieren';

  @override
  String get updatePack => 'Paket aktualisieren';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get communityContent =>
      'Die Sätze sind Beiträge der Community und möglicherweise nicht überprüft.';

  @override
  String get settingsSound => 'Ton';

  @override
  String get settingsMaster => 'Gesamt';

  @override
  String get settingsSfx => 'Effekte';

  @override
  String get settingsGameplay => 'Spieleinstellungen';

  @override
  String get settingsHaptics => 'Haptik';

  @override
  String get settingsAutoPlayVoice => 'Stimme automatisch abspielen';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsFont => 'Schrift';

  @override
  String get attributions => 'Quellenangaben';

  @override
  String get extracting => 'Entpacken…';

  @override
  String get settingsDifficulty => 'Schwierigkeit';

  @override
  String get difficultyBeginner => 'Anfänger';

  @override
  String get difficultyIntermediate => 'Mittelstufe';

  @override
  String get difficultyAdvanced => 'Fortgeschritten';

  @override
  String get settingsDailyGoal => 'Tagesziel';

  @override
  String goalTimeApprox(int minutes) {
    return '~$minutes Min.';
  }

  @override
  String get goalTierQuick => 'Schnell';

  @override
  String get goalTierShort => 'Kurz';

  @override
  String get goalTierMedium => 'Mittel';

  @override
  String get goalTierLong => 'Lang';

  @override
  String get settingsReminder => 'Erinnerung';

  @override
  String get settingsReminderTime => 'Erinnere mich um';

  @override
  String get settingsReminderPermissionDenied =>
      'Benachrichtigungen sind blockiert. Aktiviere sie in den Systemeinstellungen.';

  @override
  String get goalMetBanner => 'Tagesziel erreicht!';

  @override
  String get reminderNotificationTitle => 'Dein Dino wartet';

  @override
  String get reminderNotificationBody =>
      'Noch ein paar Schritte und das Abenteuer geht weiter.';
}
