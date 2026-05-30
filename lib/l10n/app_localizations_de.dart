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
  String get manifestUnavailable =>
      'Der Paketserver ist nicht erreichbar. Prüfe deine Verbindung und versuch es erneut.';

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
  String get settingsMusic => 'Musik';

  @override
  String get settingsGameplay => 'Spieleinstellungen';

  @override
  String get settingsHaptics => 'Haptik';

  @override
  String get settingsAutoPlayVoice => 'Stimme automatisch abspielen';

  @override
  String get settingsMusicPack => 'Musikpaket';

  @override
  String musicTrackCount(int count) {
    return '$count Titel';
  }

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
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get notifMaster => 'Vokabel-Karten';

  @override
  String get notifPerDay => 'Pro Tag';

  @override
  String get notifActiveWindow => 'Aktives Zeitfenster';

  @override
  String get notifStartTime => 'Start';

  @override
  String get notifEndTime => 'Ende';

  @override
  String get notifLanguages => 'Sprachen';

  @override
  String get notifNoPacks => 'Lade ein Paket, um Vokabel-Karten zu bekommen.';

  @override
  String get notifPreview => 'Vorschau (zum Neuwürfeln tippen)';

  @override
  String get notifPreviewEmpty => 'Wähle eine Sprache für die Vorschau.';

  @override
  String get notifPickAtLeastOne => 'Wähle mindestens eine Sprache.';

  @override
  String get clawPrizeNew => 'Neu!';

  @override
  String get clawPrizeOwned => 'Schon in deiner Sammlung';

  @override
  String get clawLost => 'Knapp daneben!';

  @override
  String get clawLostDetail => 'Versuch die nächste.';

  @override
  String clawTryAgain(int cost) {
    return 'Nochmal (${cost}c)';
  }

  @override
  String couldNotOpenUrl(String url) {
    return 'Konnte $url nicht öffnen';
  }
}
