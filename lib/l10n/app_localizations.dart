import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('nl'),
    Locale('pt'),
  ];

  /// No description provided for @packManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Language Packs'**
  String get packManagerTitle;

  /// No description provided for @packManagerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download a pack to start learning'**
  String get packManagerSubtitle;

  /// No description provided for @manifestUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the pack server. Check your connection and try again.'**
  String get manifestUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @sizeMB.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMB(String size);

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'next →'**
  String get next;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @chooseYourEgg.
  ///
  /// In en, this message translates to:
  /// **'Choose your egg!'**
  String get chooseYourEgg;

  /// No description provided for @whoWillHatch.
  ///
  /// In en, this message translates to:
  /// **'Who will hatch from it?'**
  String get whoWillHatch;

  /// No description provided for @sentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get sentences;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @updateApp.
  ///
  /// In en, this message translates to:
  /// **'Update App'**
  String get updateApp;

  /// No description provided for @updatePack.
  ///
  /// In en, this message translates to:
  /// **'Update Pack'**
  String get updatePack;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @communityContent.
  ///
  /// In en, this message translates to:
  /// **'Sentences are community-contributed and may not be reviewed.'**
  String get communityContent;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get settingsMaster;

  /// No description provided for @settingsSfx.
  ///
  /// In en, this message translates to:
  /// **'SFX'**
  String get settingsSfx;

  /// No description provided for @settingsMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get settingsMusic;

  /// No description provided for @settingsGameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get settingsGameplay;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get settingsHaptics;

  /// No description provided for @settingsAutoPlayVoice.
  ///
  /// In en, this message translates to:
  /// **'Auto-play voice'**
  String get settingsAutoPlayVoice;

  /// No description provided for @settingsMusicPack.
  ///
  /// In en, this message translates to:
  /// **'Music Pack'**
  String get settingsMusicPack;

  /// No description provided for @musicTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String musicTrackCount(int count);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get settingsFont;

  /// No description provided for @attributions.
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get attributions;

  /// No description provided for @extracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get extracting;

  /// No description provided for @settingsDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get settingsDifficulty;

  /// No description provided for @difficultyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get difficultyBeginner;

  /// No description provided for @difficultyIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get difficultyIntermediate;

  /// No description provided for @difficultyAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get difficultyAdvanced;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @notifMaster.
  ///
  /// In en, this message translates to:
  /// **'Vocab flashcards'**
  String get notifMaster;

  /// No description provided for @notifPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get notifPerDay;

  /// No description provided for @notifActiveWindow.
  ///
  /// In en, this message translates to:
  /// **'Active window'**
  String get notifActiveWindow;

  /// No description provided for @notifStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get notifStartTime;

  /// No description provided for @notifEndTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get notifEndTime;

  /// No description provided for @notifLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get notifLanguages;

  /// No description provided for @notifNoPacks.
  ///
  /// In en, this message translates to:
  /// **'Download a pack to get vocab flashcards.'**
  String get notifNoPacks;

  /// No description provided for @notifPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview (tap to re-roll)'**
  String get notifPreview;

  /// No description provided for @notifPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick a language to see a preview.'**
  String get notifPreviewEmpty;

  /// No description provided for @notifPickAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one language.'**
  String get notifPickAtLeastOne;

  /// No description provided for @clawPrizeNew.
  ///
  /// In en, this message translates to:
  /// **'New!'**
  String get clawPrizeNew;

  /// No description provided for @clawPrizeOwned.
  ///
  /// In en, this message translates to:
  /// **'Already in your collection'**
  String get clawPrizeOwned;

  /// No description provided for @clawLost.
  ///
  /// In en, this message translates to:
  /// **'So close!'**
  String get clawLost;

  /// No description provided for @clawLostDetail.
  ///
  /// In en, this message translates to:
  /// **'Try the next one.'**
  String get clawLostDetail;

  /// No description provided for @clawTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again ({cost}c)'**
  String clawTryAgain(int cost);

  /// No description provided for @couldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpenUrl(String url);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'nl',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
