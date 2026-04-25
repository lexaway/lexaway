/// External URLs the app links out to. Kept in one place so a domain change
/// or social handle update is a single edit, not a grep-and-replace.
library;

const discordInvite = 'https://discord.gg/DbGTJc7P';

const _privacyBase = 'https://lexaway.github.io/lexaway/privacy';
const _privacyLocalized = {'es', 'fr', 'de', 'it', 'pt'};

/// Privacy policy URL for the given UI language code (BCP 47 short form,
/// e.g. "fr"). Falls back to English if no localized page exists.
String privacyPolicyUrl(String languageCode) =>
    _privacyLocalized.contains(languageCode)
        ? '$_privacyBase-$languageCode.html'
        : '$_privacyBase.html';
