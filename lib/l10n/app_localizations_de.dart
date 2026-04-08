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
  String get privacyPolicy => 'Datenschutzrichtlinie';
}
