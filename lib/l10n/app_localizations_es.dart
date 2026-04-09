// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get packManagerTitle => 'Paquetes de idiomas';

  @override
  String get packManagerSubtitle =>
      'Descarga un paquete para empezar a aprender';

  @override
  String get retry => 'Reintentar';

  @override
  String downloadFailed(String error) {
    return 'Descarga fallida: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'siguiente →';

  @override
  String get appLanguage => 'Idioma de la app';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get chooseYourEgg => '¡Elige tu huevo!';

  @override
  String get whoWillHatch => '¿Quién saldrá de él?';

  @override
  String get sentences => 'Oraciones';

  @override
  String get voice => 'Voz';

  @override
  String get optional => 'Opcional';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get start => 'Comenzar';

  @override
  String get settings => 'Ajustes';

  @override
  String get updateApp => 'Actualizar App';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get communityContent =>
      'Las oraciones son contribuciones de la comunidad y pueden no estar revisadas.';

  @override
  String get settingsSound => 'Sonido';

  @override
  String get settingsMaster => 'General';

  @override
  String get settingsSfx => 'Efectos';

  @override
  String get settingsGameplay => 'Juego';

  @override
  String get settingsHaptics => 'Vibración';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get attributions => 'Atribuciones';

  @override
  String get extracting => 'Extrayendo…';
}
