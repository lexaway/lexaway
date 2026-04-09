// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get packManagerTitle => 'Pacchetti lingua';

  @override
  String get packManagerSubtitle =>
      'Scarica un pacchetto per iniziare a imparare';

  @override
  String get retry => 'Riprova';

  @override
  String downloadFailed(String error) {
    return 'Download fallito: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'avanti →';

  @override
  String get appLanguage => 'Lingua dell\'app';

  @override
  String get systemDefault => 'Predefinito di sistema';

  @override
  String get chooseYourEgg => 'Scegli il tuo uovo!';

  @override
  String get whoWillHatch => 'Chi ne uscirà?';

  @override
  String get sentences => 'Frasi';

  @override
  String get voice => 'Voce';

  @override
  String get optional => 'Facoltativo';

  @override
  String get continueLabel => 'Continua';

  @override
  String get start => 'Inizia';

  @override
  String get settings => 'Impostazioni';

  @override
  String get updateApp => 'Aggiorna l\'app';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get communityContent =>
      'Le frasi sono contributi della comunità e potrebbero non essere verificate.';

  @override
  String get settingsSound => 'Audio';

  @override
  String get settingsMaster => 'Generale';

  @override
  String get settingsSfx => 'Effetti';

  @override
  String get settingsGameplay => 'Gioco';

  @override
  String get settingsHaptics => 'Feedback aptico';

  @override
  String get settingsAbout => 'Info';

  @override
  String get attributions => 'Attribuzioni';

  @override
  String get extracting => 'Estrazione…';
}
