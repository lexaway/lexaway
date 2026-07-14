import 'package:flutter/services.dart' show rootBundle;

import 'lang_codes.dart';

/// One row from `assets/vocab.csv`. Fields are ISO 639-3 language columns;
/// access them with [translation] using either 2- or 3-letter codes.
class VocabRow {
  final int rank;
  final String eng;
  final String deu;
  final String fra;
  final String ita;
  final String nld;
  final String por;
  final String spa;

  const VocabRow({
    required this.rank,
    required this.eng,
    required this.deu,
    required this.fra,
    required this.ita,
    required this.nld,
    required this.por,
    required this.spa,
  });

  /// Lookup a translation by ISO 639-3 lang code. Returns null if the code
  /// isn't one of our seven supported languages.
  String? translation(String iso3) {
    return switch (iso3) {
      'eng' => eng,
      'deu' => deu,
      'fra' => fra,
      'ita' => ita,
      'nld' => nld,
      'por' => por,
      'spa' => spa,
      _ => null,
    };
  }
}

/// One greeting from `assets/greetings/greetings_<iso2>.csv`. [times] is the
/// set of time-of-day buckets it fits (morning/afternoon/evening/night);
/// empty means "any time".
class Greeting {
  final String text;
  final Set<String> times;
  const Greeting(this.text, this.times);

  bool fitsTime(String bucket) => times.isEmpty || times.contains(bucket);
}

/// In-memory cache so we only parse each asset once per app run.
List<VocabRow>? _vocabCache;
final Map<String, List<Greeting>> _greetingsCache = {};

Future<List<VocabRow>> loadVocab() async {
  if (_vocabCache != null) return _vocabCache!;
  final raw = await rootBundle.loadString('assets/vocab.csv');
  final rows = parseCsv(raw);
  final out = <VocabRow>[];
  // Skip header row [0].
  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    if (r.length < 8) continue;
    out.add(VocabRow(
      rank: int.tryParse(r[0]) ?? 0,
      eng: r[1],
      deu: r[2],
      fra: r[3],
      ita: r[4],
      nld: r[5],
      por: r[6],
      spa: r[7],
    ));
  }
  _vocabCache = out;
  return out;
}

/// Owns the iso3→iso2→asset-path mapping for greeting CSVs so callers can't
/// disagree on what an unknown lang means. Unknown iso3 → empty list (cached).
Future<List<Greeting>> loadGreetingsForL2(String l2Iso3) async {
  final cached = _greetingsCache[l2Iso3];
  if (cached != null) return cached;
  final iso2 = iso3to2[l2Iso3];
  if (iso2 == null) {
    _greetingsCache[l2Iso3] = const [];
    return const [];
  }
  final path = 'assets/greetings/greetings_$iso2.csv';
  final String raw;
  try {
    raw = await rootBundle.loadString(path);
  } catch (_) {
    _greetingsCache[l2Iso3] = const [];
    return const [];
  }
  final rows = parseCsv(raw);
  final out = <Greeting>[];
  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    if (r.length < 3) continue;
    final text = r[1].trim();
    if (text.isEmpty) continue;
    final timeRaw = r[2].trim();
    final times = <String>{};
    if (timeRaw.isNotEmpty && timeRaw != 'any') {
      for (final t in timeRaw.split('|')) {
        final s = t.trim();
        // Drop typos — an unknown bucket would silently never match.
        if (_knownBuckets.contains(s)) times.add(s);
      }
    }
    out.add(Greeting(text, times));
  }
  _greetingsCache[l2Iso3] = out;
  return out;
}

const _knownBuckets = {'morning', 'afternoon', 'evening', 'night'};

/// Map a 24h hour to one of our greeting time buckets.
String timeBucketForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/// Minimal RFC4180-style CSV parser: `"`-quoted fields with commas, newlines,
/// or escaped quotes (`""`). One list of fields per row; empty trailing lines
/// dropped. Public for unit testing.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  final field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  // Strip a UTF-8 BOM if the bundle handed one to us.
  var i = 0;
  if (input.startsWith('\uFEFF')) i = 1;

  while (i < input.length) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        // Doubled "" → literal quote; single " → end of quoted region.
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',') {
      row.add(field.toString());
      field.clear();
      i++;
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      row.add(field.toString());
      field.clear();
      // Skip the \n half of CRLF without emitting a blank row.
      if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      i++;
      if (row.length > 1 || row[0].isNotEmpty) rows.add(row);
      row = <String>[];
      continue;
    }
    field.write(ch);
    i++;
  }
  // Flush the final field/row if there's no trailing newline.
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.length > 1 || row[0].isNotEmpty) rows.add(row);
  }
  return rows;
}

/// Test-only: drop the in-memory caches so successive parser tests see fresh
/// state. Not called from app code.
void debugClearCsvCaches() {
  _vocabCache = null;
  _greetingsCache.clear();
}
