/// Language names in their own language. Always shown regardless of UI
/// locale, so a user stuck in the wrong UI language can still find their own.
/// Keyed by both ISO 639-1 (UI locales) and ISO 639-3 (L2 vocab packs).
const _endonyms = <String, String>{
  'de': 'Deutsch',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'pt': 'Português',
  'deu': 'Deutsch',
  'eng': 'English',
  'fra': 'Français',
  'ita': 'Italiano',
  'nld': 'Nederlands',
  'por': 'Português',
  'spa': 'Español',
};

String endonymFor(String code) => _endonyms[code] ?? code;
