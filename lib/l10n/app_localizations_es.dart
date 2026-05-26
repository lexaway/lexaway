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
  String get manifestUnavailable =>
      'No se pudo conectar al servidor de paquetes. Comprueba tu conexión e inténtalo de nuevo.';

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
  String get updatePack => 'Actualizar paquete';

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
  String get settingsMusic => 'Música';

  @override
  String get settingsGameplay => 'Juego';

  @override
  String get settingsHaptics => 'Vibración';

  @override
  String get settingsAutoPlayVoice => 'Reproducir voz automáticamente';

  @override
  String get settingsMusicPack => 'Pack de música';

  @override
  String musicTrackCount(int count) {
    return '$count pistas';
  }

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsFont => 'Fuente';

  @override
  String get attributions => 'Atribuciones';

  @override
  String get extracting => 'Extrayendo…';

  @override
  String get settingsDifficulty => 'Dificultad';

  @override
  String get difficultyBeginner => 'Principiante';

  @override
  String get difficultyIntermediate => 'Intermedio';

  @override
  String get difficultyAdvanced => 'Avanzado';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get notifMaster => 'Tarjetas de vocabulario';

  @override
  String get notifPerDay => 'Por día';

  @override
  String get notifActiveWindow => 'Franja activa';

  @override
  String get notifStartTime => 'Inicio';

  @override
  String get notifEndTime => 'Fin';

  @override
  String get notifLanguages => 'Idiomas';

  @override
  String get notifNoPacks => 'Descarga un paquete para recibir tarjetas.';

  @override
  String get notifPreview => 'Vista previa (toca para refrescar)';

  @override
  String get notifPreviewEmpty => 'Elige un idioma para ver la vista previa.';

  @override
  String get notifPickAtLeastOne => 'Elige al menos un idioma.';
}
