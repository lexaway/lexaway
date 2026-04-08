import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/models/question.dart';

/// Curated questions for App Store screenshots.
/// Keep this list small — QuestionPanel shuffles internally, and a single
/// question guarantees the game screenshot always shows this exact sentence.
const screenshotQuestions = [
  Question(
    phrase: 'Le chat dort sur le canapé',
    translation: 'The cat sleeps on the couch',
    blankIndex: 20,
    answer: 'canapé',
    options: ['canapé', 'jardin', 'livre', 'chapeau'],
  ),
];

const screenshotManifest = Manifest(
  schemaVersion: 1,
  packs: [
    PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: '🇫🇷',
      builtAt: '2026-04-01',
      schemaVersion: 1,
    ),
    PackInfo(
      lang: 'spa',
      fromLang: 'eng',
      name: 'Spanish',
      flag: '🇪🇸',
      builtAt: '2026-04-01',
      schemaVersion: 1,
    ),
    PackInfo(
      lang: 'deu',
      fromLang: 'eng',
      name: 'German',
      flag: '🇩🇪',
      builtAt: '2026-04-01',
      schemaVersion: 1,
    ),
    PackInfo(
      lang: 'ita',
      fromLang: 'eng',
      name: 'Italian',
      flag: '🇮🇹',
      builtAt: '2026-04-01',
      schemaVersion: 1,
    ),
  ],
);

const screenshotLocalPacks = <String, LocalPack>{
  'eng-fra': LocalPack(
    lang: 'fra',
    fromLang: 'eng',
    schemaVersion: 1,
    builtAt: '2026-04-01',
    sizeBytes: 5242880,
  ),
};
