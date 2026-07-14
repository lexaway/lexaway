/// External URLs the app links out to. One place so domain/handle changes are a single edit.
library;

const discordInvite = 'https://discord.gg/DbGTJc7P';

const _privacyBase = 'https://lexaway.github.io/lexaway/privacy';
const _privacyLocalized = {'es', 'fr', 'de', 'it', 'pt'};

/// Privacy policy URL for a UI language code (BCP 47 short form, e.g. "fr").
/// Falls back to English if no localized page exists.
String privacyPolicyUrl(String languageCode) =>
    _privacyLocalized.contains(languageCode)
        ? '$_privacyBase-$languageCode.html'
        : '$_privacyBase.html';
