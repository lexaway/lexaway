import 'package:flutter/material.dart';

import '../models/question.dart';

/// Renders a phrase with one word displayed as a fill-in-the-blank.
///
/// Punctuation attached to the same whitespace-delimited word as the answer is
/// preserved around the blank — `¿Crees que es viejo?` with `answer: 'Crees'`
/// renders as `¿____ que es viejo?` before reveal.
///
/// [onTapWord] is invoked with the containing word's text — the same token
/// shape `Question.words` produces, so the TTS prefetcher and the tap handler
/// hit the same cache key. Not called for taps on an unrevealed blank.
class PhraseText extends StatelessWidget {
  final String phrase;
  final int blankIndex;
  final String answer;
  final bool revealed;
  final Color blankColor;
  final Color textColor;
  final void Function(String text)? onTapWord;

  const PhraseText({
    super.key,
    required this.phrase,
    required this.blankIndex,
    required this.answer,
    required this.revealed,
    required this.blankColor,
    required this.textColor,
    this.onTapWord,
  });

  @override
  Widget build(BuildContext context) {
    final words = splitPhraseWords(phrase);
    final blankWordIdx = findBlankWordIndex(words, blankIndex);

    final baseStyle = TextStyle(
      color: textColor,
      fontSize: 20,
      height: 1.1,
    );

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < words.length; i++) ...[
            if (i > 0) const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _buildWord(
                word: words[i],
                isBlank: i == blankWordIdx,
                baseStyle: baseStyle,
              ),
            ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWord({
    required PhraseWord word,
    required bool isBlank,
    required TextStyle baseStyle,
  }) {
    if (!isBlank) {
      return GestureDetector(
        onTap: onTapWord == null ? null : () => onTapWord!(word.text),
        child: Text(word.text, style: baseStyle),
      );
    }

    final blankStart = blankIndex - word.start;
    final blankEnd = blankStart + answer.length;

    // If the stored range escapes the word boundaries, blank the whole word.
    final safe = blankStart >= 0 && blankEnd <= word.text.length;
    final prefix = safe ? word.text.substring(0, blankStart) : '';
    final suffix = safe ? word.text.substring(blankEnd) : '';
    final blankText = revealed ? answer : '____';

    return GestureDetector(
      onTap: () {
        if (!revealed) return;
        onTapWord?.call(word.text);
      },
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            if (prefix.isNotEmpty) TextSpan(text: prefix),
            TextSpan(
              text: blankText,
              style: TextStyle(
                color: blankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (suffix.isNotEmpty) TextSpan(text: suffix),
          ],
        ),
      ),
    );
  }
}
