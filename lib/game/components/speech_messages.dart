import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _rng = Random();

class DinoVoice {
  final List<String> correct;
  final Map<int, String> streak;
  final List<String> wrong;
  final List<String> idle;

  const DinoVoice({
    required this.correct,
    required this.streak,
    required this.wrong,
    required this.idle,
  });

  factory DinoVoice.fromJson(Map<String, dynamic> json) {
    return DinoVoice(
      correct: List<String>.from(json['correct']),
      streak: (json['streak'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      wrong: List<String>.from(json['wrong']),
      idle: List<String>.from(json['idle']),
    );
  }
}

/// Loads and caches dino voice data per locale from asset JSON files.
class SpeechMessages {
  static final _cache = <String, DinoVoice>{};

  static Future<bool> load(String locale) async {
    if (_cache.containsKey(locale)) return true;
    try {
      final json = await rootBundle.loadString('assets/dino/$locale.json');
      _cache[locale] = DinoVoice.fromJson(jsonDecode(json));
      return true;
    } on FlutterError {
      // Asset file doesn't exist for this locale — fall back to 'en'.
      return false;
    }
  }

  static DinoVoice _voice(String locale) =>
      _cache[locale] ?? _cache['en'] ?? _fallback;

  static const _fallback = DinoVoice(
    correct: ['Nice!'],
    streak: {5: 'On fire!', 10: 'Unstoppable!', 25: 'LEGENDARY'},
    wrong: ['Ouch'],
    idle: ['...'],
  );

  static String? pickCorrectMessage(
    int streak,
    String answer, {
    String locale = 'en',
  }) {
    final voice = _voice(locale);
    if (voice.streak.containsKey(streak)) return voice.streak[streak];

    if (_rng.nextInt(4) != 0) return null;
    if (_rng.nextInt(3) == 0 && answer.length <= 12) return '$answer!';

    return voice.correct[_rng.nextInt(voice.correct.length)];
  }

  static String? pickWrongMessage({String locale = 'en'}) {
    if (_rng.nextInt(3) != 0) return null;

    final voice = _voice(locale);
    return voice.wrong[_rng.nextInt(voice.wrong.length)];
  }

  static String pickIdleMessage({String locale = 'en'}) {
    final voice = _voice(locale);
    return voice.idle[_rng.nextInt(voice.idle.length)];
  }
}
