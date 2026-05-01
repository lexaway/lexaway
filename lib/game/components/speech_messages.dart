import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _rng = Random();

typedef Buckets = Map<String, List<String>>;

class DinoVoice {
  final Buckets correct;
  final Map<int, String> streak;
  final Buckets wrong;
  final Buckets idle;

  const DinoVoice({
    required this.correct,
    required this.streak,
    required this.wrong,
    required this.idle,
  });

  factory DinoVoice.fromJson(Map<String, dynamic> json) {
    return DinoVoice(
      correct: _parseBuckets(json['correct']),
      streak: (json['streak'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      wrong: _parseBuckets(json['wrong']),
      idle: _parseBuckets(json['idle']),
    );
  }

  static Buckets _parseBuckets(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, List<String>.from(v as List)));
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
    } catch (e, st) {
      // Malformed JSON or schema mismatch — log and fall back rather than crash.
      debugPrint('SpeechMessages: failed to parse $locale.json: $e\n$st');
      return false;
    }
  }

  static DinoVoice _voice(String locale) =>
      _cache[locale] ?? _cache['en'] ?? _fallback;

  static const _fallback = DinoVoice(
    correct: {
      'casual': ['Nice!'],
    },
    streak: {5: 'On fire!', 10: 'Unstoppable!', 25: 'LEGENDARY'},
    wrong: {
      'soft': ['Ouch'],
    },
    idle: {
      'sleepy': ['...'],
    },
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

    return _pickFromBuckets(voice.correct, _correctWeights(streak));
  }

  static String? pickWrongMessage({String locale = 'en'}) {
    if (_rng.nextInt(3) != 0) return null;

    final voice = _voice(locale);
    return _pickFromBuckets(voice.wrong, _wrongWeights);
  }

  static String pickIdleMessage({String locale = 'en'}) {
    final voice = _voice(locale);
    // Even-weight all idle buckets (weights default to 1 for unlisted keys).
    // New buckets added to JSON are auto-included with weight 1.
    return _pickFromBuckets(voice.idle, const {}) ?? '...';
  }

  /// Pick a bucket by weight (defaulting to 1 for unlisted keys), then a
  /// uniform random item from that bucket. Returns null only if every bucket
  /// is empty.
  static String? _pickFromBuckets(Buckets buckets, Map<String, int> weights) {
    final entries = buckets.entries
        .where((e) => e.value.isNotEmpty)
        .toList(growable: false);
    if (entries.isEmpty) return null;

    var total = 0;
    final cumulative = <int>[];
    for (final e in entries) {
      total += weights[e.key] ?? 1;
      cumulative.add(total);
    }
    if (total <= 0) return null;

    final roll = _rng.nextInt(total);
    var idx = 0;
    while (idx < cumulative.length && cumulative[idx] <= roll) {
      idx++;
    }
    final bucket = entries[idx].value;
    return bucket[_rng.nextInt(bucket.length)];
  }

  static Map<String, int> _correctWeights(int streak) {
    if (streak >= 10) {
      return const {
        'casual': 1,
        'silly': 1,
        'food': 2,
        'dino': 3,
        'epic': 4,
      };
    }
    if (streak >= 3) {
      return const {
        'casual': 3,
        'silly': 3,
        'food': 3,
        'dino': 3,
        'epic': 1,
      };
    }
    return const {
      'casual': 3,
      'silly': 3,
      'food': 3,
      'dino': 3,
      'epic': 0,
    };
  }

  static const _wrongWeights = {
    'soft': 6,
    'dino': 3,
    'dramatic': 1,
  };
}
