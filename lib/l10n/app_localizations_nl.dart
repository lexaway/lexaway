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
  String get manifestUnavailable =>
      'Kan de pakketserver niet bereiken. Controleer je verbinding en probeer het opnieuw.';

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
  String get settingsMusicPack => 'Muziekpakket';

  @override
  String musicTrackCount(int count) {
    return '$count nummers';
  }

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
  String get settingsNotifications => 'Meldingen';

  @override
  String get notifMaster => 'Woordkaarten';

  @override
  String get notifPerDay => 'Per dag';

  @override
  String get notifActiveWindow => 'Actieve periode';

  @override
  String get notifStartTime => 'Begin';

  @override
  String get notifEndTime => 'Eind';

  @override
  String get notifLanguages => 'Talen';

  @override
  String get notifNoPacks => 'Download een pakket voor woordkaarten.';

  @override
  String get notifPreview => 'Voorbeeld (tik om te verversen)';

  @override
  String get notifPreviewEmpty => 'Kies een taal voor een voorbeeld.';

  @override
  String get notifPickAtLeastOne => 'Kies ten minste één taal.';

  @override
  String get clawPrizeNew => 'Nieuw!';

  @override
  String get clawPrizeOwned => 'Al in je collectie';

  @override
  String get clawLost => 'Net niet!';

  @override
  String get clawLostDetail => 'Probeer de volgende.';

  @override
  String clawTryAgain(int cost) {
    return 'Opnieuw (${cost}c)';
  }

  @override
  String get collection => 'Collectie';

  @override
  String couldNotOpenUrl(String url) {
    return 'Kan $url niet openen';
  }
}
