import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/models/question.dart';

/// Per-locale screenshot data. When the UI is in a given language, we show
/// learning English *from* that language — except for English, where we show
/// learning French from English.
class ScreenshotLocaleData {
  final String packId;
  final String activeLang;
  final List<Question> questions;
  final Map<String, LocalPack> localPacks;
  final Manifest manifest;
  final String characterKey; // e.g. 'fra' or 'eng'

  const ScreenshotLocaleData({
    required this.packId,
    required this.activeLang,
    required this.questions,
    required this.localPacks,
    required this.manifest,
    required this.characterKey,
  });
}

const _baseManifest = [
  PackInfo(lang: 'fra', fromLang: 'eng', name: 'French', flag: '🇫🇷', builtAt: '2026-04-01', schemaVersion: 1),
  PackInfo(lang: 'spa', fromLang: 'eng', name: 'Spanish', flag: '🇪🇸', builtAt: '2026-04-01', schemaVersion: 1),
  PackInfo(lang: 'deu', fromLang: 'eng', name: 'German', flag: '🇩🇪', builtAt: '2026-04-01', schemaVersion: 1),
  PackInfo(lang: 'ita', fromLang: 'eng', name: 'Italian', flag: '🇮🇹', builtAt: '2026-04-01', schemaVersion: 1),
];

LocalPack _localPack(String fromLang, String lang) => LocalPack(
  lang: lang,
  fromLang: fromLang,
  schemaVersion: 1,
  builtAt: '2026-04-01',
  sizeBytes: 5242880,
);

final screenshotLocaleData = <String, ScreenshotLocaleData>{
  'en': ScreenshotLocaleData(
    packId: 'eng-fra',
    activeLang: 'fra',
    characterKey: 'fra',
    questions: const [
      Question(
        phrase: 'Le chat dort sur le canapé',
        translation: 'The cat sleeps on the couch',
        blankIndex: 20,
        answer: 'canapé',
        options: ['canapé', 'jardin', 'livre', 'chapeau'],
      ),
    ],
    localPacks: {'eng-fra': _localPack('eng', 'fra')},
    manifest: const Manifest(schemaVersion: 1, packs: _baseManifest),
  ),
  'fr': ScreenshotLocaleData(
    packId: 'fra-eng',
    activeLang: 'eng',
    characterKey: 'eng',
    questions: const [
      Question(
        phrase: 'The cat sleeps on the couch',
        translation: 'Le chat dort sur le canapé',
        blankIndex: 18,
        answer: 'the couch',
        options: ['the couch', 'the garden', 'the book', 'the hat'],
      ),
    ],
    localPacks: {'fra-eng': _localPack('fra', 'eng')},
    manifest: const Manifest(schemaVersion: 1, packs: [
      PackInfo(lang: 'eng', fromLang: 'fra', name: 'Anglais', flag: '🇬🇧', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'spa', fromLang: 'fra', name: 'Espagnol', flag: '🇪🇸', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'deu', fromLang: 'fra', name: 'Allemand', flag: '🇩🇪', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'ita', fromLang: 'fra', name: 'Italien', flag: '🇮🇹', builtAt: '2026-04-01', schemaVersion: 1),
    ]),
  ),
  'de': ScreenshotLocaleData(
    packId: 'deu-eng',
    activeLang: 'eng',
    characterKey: 'eng',
    questions: const [
      Question(
        phrase: 'The cat sleeps on the couch',
        translation: 'Die Katze schläft auf dem Sofa',
        blankIndex: 18,
        answer: 'the couch',
        options: ['the couch', 'the garden', 'the book', 'the hat'],
      ),
    ],
    localPacks: {'deu-eng': _localPack('deu', 'eng')},
    manifest: const Manifest(schemaVersion: 1, packs: [
      PackInfo(lang: 'eng', fromLang: 'deu', name: 'Englisch', flag: '🇬🇧', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'fra', fromLang: 'deu', name: 'Französisch', flag: '🇫🇷', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'spa', fromLang: 'deu', name: 'Spanisch', flag: '🇪🇸', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'ita', fromLang: 'deu', name: 'Italienisch', flag: '🇮🇹', builtAt: '2026-04-01', schemaVersion: 1),
    ]),
  ),
  'es': ScreenshotLocaleData(
    packId: 'spa-eng',
    activeLang: 'eng',
    characterKey: 'eng',
    questions: const [
      Question(
        phrase: 'The cat sleeps on the couch',
        translation: 'El gato duerme en el sofá',
        blankIndex: 18,
        answer: 'the couch',
        options: ['the couch', 'the garden', 'the book', 'the hat'],
      ),
    ],
    localPacks: {'spa-eng': _localPack('spa', 'eng')},
    manifest: const Manifest(schemaVersion: 1, packs: [
      PackInfo(lang: 'eng', fromLang: 'spa', name: 'Inglés', flag: '🇬🇧', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'fra', fromLang: 'spa', name: 'Francés', flag: '🇫🇷', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'deu', fromLang: 'spa', name: 'Alemán', flag: '🇩🇪', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'ita', fromLang: 'spa', name: 'Italiano', flag: '🇮🇹', builtAt: '2026-04-01', schemaVersion: 1),
    ]),
  ),
  'it': ScreenshotLocaleData(
    packId: 'ita-eng',
    activeLang: 'eng',
    characterKey: 'eng',
    questions: const [
      Question(
        phrase: 'The cat sleeps on the couch',
        translation: 'Il gatto dorme sul divano',
        blankIndex: 18,
        answer: 'the couch',
        options: ['the couch', 'the garden', 'the book', 'the hat'],
      ),
    ],
    localPacks: {'ita-eng': _localPack('ita', 'eng')},
    manifest: const Manifest(schemaVersion: 1, packs: [
      PackInfo(lang: 'eng', fromLang: 'ita', name: 'Inglese', flag: '🇬🇧', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'fra', fromLang: 'ita', name: 'Francese', flag: '🇫🇷', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'spa', fromLang: 'ita', name: 'Spagnolo', flag: '🇪🇸', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'deu', fromLang: 'ita', name: 'Tedesco', flag: '🇩🇪', builtAt: '2026-04-01', schemaVersion: 1),
    ]),
  ),
  'pt': ScreenshotLocaleData(
    packId: 'por-eng',
    activeLang: 'eng',
    characterKey: 'eng',
    questions: const [
      Question(
        phrase: 'The cat sleeps on the couch',
        translation: 'O gato dorme no sofá',
        blankIndex: 18,
        answer: 'the couch',
        options: ['the couch', 'the garden', 'the book', 'the hat'],
      ),
    ],
    localPacks: {'por-eng': _localPack('por', 'eng')},
    manifest: const Manifest(schemaVersion: 1, packs: [
      PackInfo(lang: 'eng', fromLang: 'por', name: 'Inglês', flag: '🇬🇧', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'fra', fromLang: 'por', name: 'Francês', flag: '🇫🇷', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'spa', fromLang: 'por', name: 'Espanhol', flag: '🇪🇸', builtAt: '2026-04-01', schemaVersion: 1),
      PackInfo(lang: 'deu', fromLang: 'por', name: 'Alemão', flag: '🇩🇪', builtAt: '2026-04-01', schemaVersion: 1),
    ]),
  ),
};
