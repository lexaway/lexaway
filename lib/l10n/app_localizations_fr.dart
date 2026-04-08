// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get packManagerTitle => 'Paquets de langues';

  @override
  String get packManagerSubtitle =>
      'Télécharge un paquet pour commencer à apprendre';

  @override
  String get retry => 'Réessayer';

  @override
  String downloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String sizeMB(String size) {
    return '$size Mo';
  }

  @override
  String get next => 'suivant →';

  @override
  String get appLanguage => 'Langue de l\'appli';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get chooseYourEgg => 'Choisis ton œuf !';

  @override
  String get whoWillHatch => 'Qui va en sortir ?';

  @override
  String get sentences => 'Phrases';

  @override
  String get voice => 'Voix';

  @override
  String get optional => 'Facultatif';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get start => 'Commencer';

  @override
  String get settings => 'Paramètres';

  @override
  String get updateApp => 'Mettre à jour l\'appli';

  @override
  String get privacyPolicy => 'Politique de confidentialité';
}
