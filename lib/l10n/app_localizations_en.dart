// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get packManagerTitle => 'Language Packs';

  @override
  String get packManagerSubtitle => 'Download a pack to start learning';

  @override
  String get retry => 'Retry';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String sizeMB(String size) {
    return '$size MB';
  }

  @override
  String get next => 'next →';

  @override
  String get appLanguage => 'App Language';

  @override
  String get systemDefault => 'System default';
}
