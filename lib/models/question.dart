import 'dart:convert';

class Question {
  final String phrase;
  final String translation;
  final int blankIndex;
  final String answer;
  final List<String> options;

  const Question({
    required this.phrase,
    required this.translation,
    required this.blankIndex,
    required this.answer,
    required this.options,
  });

  factory Question.fromMap(Map<String, dynamic> row) {
    return Question(
      phrase: row['phrase'] as String,
      translation: row['translation'] as String,
      blankIndex: row['blank_index'] as int,
      answer: row['answer'] as String,
      options: (jsonDecode(row['options'] as String) as List).cast<String>(),
    );
  }

  /// Text before the blank
  String get before => phrase.substring(0, blankIndex);

  /// Text after the blank
  String get after => phrase.substring(blankIndex + answer.length);
}
