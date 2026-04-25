// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get packManagerTitle => 'Pacotes de idiomas';

  @override
  String get packManagerSubtitle => 'Baixe um pacote para começar a aprender';

  @override
  String get retry => 'Tentar novamente';

  @override
  String downloadFailed(String error) {
    return 'Falha no download: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'próximo →';

  @override
  String get appLanguage => 'Idioma do app';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get chooseYourEgg => 'Escolha seu ovo!';

  @override
  String get whoWillHatch => 'Quem vai chocar?';

  @override
  String get sentences => 'Frases';

  @override
  String get voice => 'Voz';

  @override
  String get optional => 'Opcional';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get start => 'Começar';

  @override
  String get settings => 'Configurações';

  @override
  String get updateApp => 'Atualizar o app';

  @override
  String get updatePack => 'Atualizar pacote';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get communityContent =>
      'As frases são contribuições da comunidade e podem não ter sido revisadas.';

  @override
  String get settingsSound => 'Som';

  @override
  String get settingsMaster => 'Geral';

  @override
  String get settingsSfx => 'Efeitos';

  @override
  String get settingsMusic => 'Música';

  @override
  String get settingsGameplay => 'Jogabilidade';

  @override
  String get settingsHaptics => 'Vibração';

  @override
  String get settingsAutoPlayVoice => 'Reproduzir voz automaticamente';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsFont => 'Fonte';

  @override
  String get attributions => 'Atribuições';

  @override
  String get extracting => 'Extraindo…';

  @override
  String get settingsDifficulty => 'Dificuldade';

  @override
  String get difficultyBeginner => 'Iniciante';

  @override
  String get difficultyIntermediate => 'Intermediário';

  @override
  String get difficultyAdvanced => 'Avançado';

  @override
  String get settingsDailyGoal => 'Meta diária';

  @override
  String goalTimeApprox(int minutes) {
    return '~$minutes min';
  }

  @override
  String get goalTierQuick => 'Rápida';

  @override
  String get goalTierShort => 'Curta';

  @override
  String get goalTierMedium => 'Média';

  @override
  String get goalTierLong => 'Longa';

  @override
  String get settingsReminder => 'Lembrete';

  @override
  String get settingsReminderTime => 'Lembrar às';

  @override
  String get settingsReminderPermissionDenied =>
      'As notificações estão bloqueadas. Ative-as nas configurações do sistema.';

  @override
  String get goalMetBanner => 'Meta diária atingida!';

  @override
  String get reminderNotificationTitle => 'Seu dino está esperando';

  @override
  String get reminderNotificationBody => 'Alguns passos e a aventura continua.';
}
