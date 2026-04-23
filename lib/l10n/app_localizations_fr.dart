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
  String get updatePack => 'Mettre à jour le paquet';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get communityContent =>
      'Les phrases sont des contributions communautaires et peuvent ne pas être vérifiées.';

  @override
  String get settingsSound => 'Son';

  @override
  String get settingsMaster => 'Général';

  @override
  String get settingsSfx => 'Effets';

  @override
  String get settingsGameplay => 'Jeu';

  @override
  String get settingsHaptics => 'Haptique';

  @override
  String get settingsAutoPlayVoice => 'Lecture vocale automatique';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsFont => 'Police';

  @override
  String get attributions => 'Attributions';

  @override
  String get extracting => 'Extraction…';

  @override
  String get settingsDifficulty => 'Difficulté';

  @override
  String get difficultyBeginner => 'Débutant';

  @override
  String get difficultyIntermediate => 'Intermédiaire';

  @override
  String get difficultyAdvanced => 'Avancé';

  @override
  String get settingsDailyGoal => 'Objectif quotidien';

  @override
  String goalTimeApprox(int minutes) {
    return '~$minutes min';
  }

  @override
  String get goalTierQuick => 'Rapide';

  @override
  String get goalTierShort => 'Courte';

  @override
  String get goalTierMedium => 'Moyenne';

  @override
  String get goalTierLong => 'Longue';

  @override
  String get settingsReminder => 'Rappel';

  @override
  String get settingsReminderTime => 'Me rappeler à';

  @override
  String get settingsReminderPermissionDenied =>
      'Les notifications sont bloquées. Active-les dans les réglages du système.';

  @override
  String get goalMetBanner => 'Objectif du jour atteint !';

  @override
  String get reminderNotificationTitle => 'Ton dino t\'attend';

  @override
  String get reminderNotificationBody =>
      'Quelques pas et l\'aventure continue.';
}
