import 'dart:convert';

class Question {
  final int id;
  final String phrase;
  final String translation;
  final int blankIndex;
  final String answer;
  final List<String> options;

  // SM-2 state — carried along so recordAnswer can compute the next state.
  final double easiness;
  final int intervalDays;
  final int repetitions;

  const Question({
    required this.id,
    required this.phrase,
    required this.translation,
    required this.blankIndex,
    required this.answer,
    required this.options,
    this.easiness = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
  });

  factory Question.fromMap(Map<String, dynamic> row) {
    return Question(
      id: row['id'] as int,
      phrase: row['phrase'] as String,
      translation: row['translation'] as String,
      blankIndex: row['blank_index'] as int,
      answer: row['answer'] as String,
      options: (jsonDecode(row['options'] as String) as List).cast<String>(),
      easiness: (row['easiness'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (row['interval_days'] as num?)?.toInt() ?? 0,
      repetitions: (row['repetitions'] as num?)?.toInt() ?? 0,
    );
  }

  String get before => phrase.substring(0, blankIndex);

  String get after => phrase.substring(blankIndex + answer.length);

  /// Non-whitespace runs, matching the tokens rendered by [PhraseText], so the
  /// TTS prefetcher's cache keys line up with what the tap handler requests.
  List<String> get words =>
      splitPhraseWords(phrase).map((w) => w.text).toList();
}

/// A non-whitespace run within a phrase, annotated with its character
/// offsets in the original string.
class PhraseWord {
  final String text;

  /// Inclusive start character offset in the phrase.
  final int start;

  /// Exclusive end character offset in the phrase.
  final int end;

  const PhraseWord(this.text, this.start, this.end);
}

/// Split [phrase] into non-whitespace runs, each tagged with the
/// character range it occupies in the original string.
///
/// Unlike `phrase.split(RegExp(r'\s+'))`, the offsets stay correct when
/// the phrase contains leading whitespace, multiple consecutive spaces,
/// tabs, newlines, or non-breaking spaces.
List<PhraseWord> splitPhraseWords(String phrase) {
  final words = <PhraseWord>[];
  for (final match in RegExp(r'\S+').allMatches(phrase)) {
    words.add(PhraseWord(match.group(0)!, match.start, match.end));
  }
  return words;
}

/// Return the index of the word in [words] whose character range contains
/// [blankIndex], or `-1` if no word contains that offset.
///
/// Containment is half-open: a word covers `[start, end)`. An offset that
/// falls on whitespace between words returns `-1`.
int findBlankWordIndex(List<PhraseWord> words, int blankIndex) {
  for (var i = 0; i < words.length; i++) {
    if (blankIndex >= words[i].start && blankIndex < words[i].end) {
      return i;
    }
  }
  return -1;
}
