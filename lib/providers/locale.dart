import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_keys.dart';
import '../data/lang_codes.dart';
import 'bootstrap.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final tag = ref.read(hiveBoxProvider).get(HiveKeys.uiLocale) as String?;
    if (tag == null) return null;
    final parts = tag.split('-');
    return switch (parts.length) {
      1 => Locale(parts[0]),
      2 => Locale(parts[0], parts[1]),
      _ => Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts.length > 2 ? parts[1] : null,
        countryCode: parts.last,
      ),
    };
  }

  void setLocale(Locale? locale) {
    state = locale;
    final box = ref.read(hiveBoxProvider);
    if (locale != null) {
      box.put(HiveKeys.uiLocale, locale.toLanguageTag());
    } else {
      box.delete(HiveKeys.uiLocale);
    }
  }
}

// Native language (ISO 639-3, derived from locale)

final nativeLangProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  final code = locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return iso2to3[code] ?? 'eng';
});
