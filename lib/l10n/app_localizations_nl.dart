// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get packManagerTitle => 'Taalpakketten';

  @override
  String get packManagerSubtitle => 'Download een pakket om te beginnen';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String downloadFailed(String error) {
    return 'Download mislukt: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'verder →';

  @override
  String get appLanguage => 'App-taal';

  @override
  String get systemDefault => 'Systeemstandaard';

  @override
  String get chooseYourEgg => 'Kies je ei!';

  @override
  String get whoWillHatch => 'Wie komt eruit?';

  @override
  String get sentences => 'Zinnen';

  @override
  String get voice => 'Stem';

  @override
  String get optional => 'Optioneel';

  @override
  String get continueLabel => 'Verder';

  @override
  String get start => 'Starten';

  @override
  String get settings => 'Instellingen';

  @override
  String get updateApp => 'App bijwerken';

  @override
  String get updatePack => 'Pakket bijwerken';

  @override
  String get privacyPolicy => 'Privacybeleid';

  @override
  String get communityContent =>
      'Zinnen zijn bijdragen van de community en zijn mogelijk niet gecontroleerd.';

  @override
  String get settingsSound => 'Geluid';

  @override
  String get settingsMaster => 'Hoofdvolume';

  @override
  String get settingsSfx => 'Effecten';

  @override
  String get settingsMusic => 'Muziek';

  @override
  String get settingsGameplay => 'Gameplay';

  @override
  String get settingsHaptics => 'Trillingen';

  @override
  String get settingsAutoPlayVoice => 'Stem automatisch afspelen';

  @override
  String get settingsAbout => 'Over';

  @override
  String get settingsFont => 'Lettertype';

  @override
  String get attributions => 'Vermeldingen';

  @override
  String get extracting => 'Uitpakken…';

  @override
  String get settingsDifficulty => 'Moeilijkheid';

  @override
  String get difficultyBeginner => 'Beginner';

  @override
  String get difficultyIntermediate => 'Gemiddeld';

  @override
  String get difficultyAdvanced => 'Gevorderd';

  @override
  String get settingsDailyGoal => 'Dagdoel';

  @override
  String goalTimeApprox(int minutes) {
    return '~$minutes min';
  }

  @override
  String get goalTierQuick => 'Snel';

  @override
  String get goalTierShort => 'Kort';

  @override
  String get goalTierMedium => 'Middel';

  @override
  String get goalTierLong => 'Lang';

  @override
  String get settingsReminder => 'Herinnering';

  @override
  String get settingsReminderTime => 'Herinner me om';

  @override
  String get settingsReminderPermissionDenied =>
      'Meldingen zijn geblokkeerd. Schakel ze in via de systeeminstellingen.';

  @override
  String get goalMetBanner => 'Dagdoel behaald!';

  @override
  String get reminderNotificationTitle => 'Je dino wacht';

  @override
  String get reminderNotificationBody =>
      'Een paar stapjes en het avontuur gaat door.';
}
