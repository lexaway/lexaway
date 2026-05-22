import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/models/question.dart';
import 'package:lexaway/widgets/phrase_text.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.ltr,
            child: child,
          ),
        ),
      );

  /// Concatenates all Text.rich spans the widget tree produced so tests can
  /// assert on the rendered text in one pass, including punctuation that's
  /// glued to the blank span.
  String renderedText(WidgetTester tester) {
    final buffer = StringBuffer();
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final span = text.textSpan;
      if (span != null) {
        buffer.write(span.toPlainText(includeSemanticsLabels: false));
      } else if (text.data != null) {
        buffer.write(text.data);
      }
    }
    return buffer.toString();
  }

  group('PhraseText — unrevealed blank', () {
    testWidgets('renders ____ on a plain ASCII phrase', (tester) async {
      await tester.pumpWidget(wrap(const PhraseText(
        phrase: 'the quick fox',
        blankIndex: 4, // 'quick'
        answer: 'quick',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
      )));

      final rendered = renderedText(tester);
      expect(rendered, contains('____'));
      expect(rendered, isNot(contains('quick')));
      expect(rendered, contains('the'));
      expect(rendered, contains('fox'));
    });

    testWidgets('regression: ¿Crees que es viejo? blanks Crees', (tester) async {
      // Before the fix, this phrase rendered with no blank at all —
      // the algorithm walked cumulative offsets and missed blankIndex=1
      // because '¿Crees' starts at offset 0 in a whitespace split.
      await tester.pumpWidget(wrap(const PhraseText(
        phrase: '¿Crees que es viejo?',
        blankIndex: 1,
        answer: 'Crees',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
      )));

      final rendered = renderedText(tester);
      expect(rendered, contains('____'),
          reason: 'the blank must actually appear in the rendered phrase');
      expect(rendered, isNot(contains('Crees')),
          reason: 'the answer must be hidden before the user answers');
      // Punctuation around the blank word is preserved.
      expect(rendered, contains('¿'));
      expect(rendered, contains('que'));
      expect(rendered, contains('es'));
      expect(rendered, contains('viejo?'));
    });

    testWidgets('preserves trailing punctuation around the blank', (tester) async {
      await tester.pumpWidget(wrap(const PhraseText(
        phrase: 'Es muy viejo.',
        blankIndex: 7, // 'viejo'
        answer: 'viejo',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
      )));

      final rendered = renderedText(tester);
      expect(rendered, contains('____'));
      expect(rendered, contains('.'),
          reason: 'trailing period should survive the blank');
      expect(rendered, isNot(contains('viejo')));
    });

    testWidgets('blanks a word that appears later in the sentence', (tester) async {
      await tester.pumpWidget(wrap(const PhraseText(
        phrase: '¿Crees que es viejo?',
        blankIndex: 14, // 'viejo'
        answer: 'viejo',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
      )));

      final rendered = renderedText(tester);
      expect(rendered, contains('____'));
      expect(rendered, isNot(contains('viejo')));
      // The leading ¿ word must still render intact.
      expect(rendered, contains('¿Crees'));
    });
  });

  group('PhraseText — revealed blank', () {
    testWidgets('shows the full phrase once revealed', (tester) async {
      await tester.pumpWidget(wrap(const PhraseText(
        phrase: '¿Crees que es viejo?',
        blankIndex: 1,
        answer: 'Crees',
        revealed: true,
        blankColor: Colors.green,
        textColor: Colors.white,
      )));

      final rendered = renderedText(tester);
      expect(rendered, isNot(contains('____')));
      expect(rendered, contains('¿Crees'),
          reason: 'after reveal, the ¿ prefix and the answer should be '
              'reunited as the original word');
      expect(rendered, contains('viejo?'));
    });
  });

  group('PhraseText — taps', () {
    testWidgets('tapping a non-blank word fires onTapWord with the word', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(wrap(PhraseText(
        phrase: 'the quick fox',
        blankIndex: 4,
        answer: 'quick',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
        onTapWord: tapped.add,
      )));

      await tester.tap(find.text('the'));
      await tester.tap(find.text('fox'));
      expect(tapped, ['the', 'fox']);
    });

    testWidgets('tapping an unrevealed blank does not fire onTapWord', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(wrap(PhraseText(
        phrase: 'the quick fox',
        blankIndex: 4,
        answer: 'quick',
        revealed: false,
        blankColor: Colors.orange,
        textColor: Colors.white,
        onTapWord: tapped.add,
      )));

      // Tap the rendered blank word (the Text.rich built from 'quick').
      await tester.tap(find.textContaining('____'));
      expect(tapped, isEmpty);
    });

    testWidgets('tapping a revealed blank fires onTapWord with the containing word', (tester) async {
      // Regression for the TTS cache-key mismatch: the prefetcher warms
      // '¿Crees' (via Question.words), so the tap handler must request
      // '¿Crees' too — not the bare 'Crees'.
      final tapped = <String>[];
      await tester.pumpWidget(wrap(PhraseText(
        phrase: '¿Crees que es viejo?',
        blankIndex: 1,
        answer: 'Crees',
        revealed: true,
        blankColor: Colors.green,
        textColor: Colors.white,
        onTapWord: tapped.add,
      )));

      await tester.tap(find.textContaining('¿Crees'));
      expect(tapped, ['¿Crees']);
    });
  });

  group('Question.words <-> PhraseText consistency', () {
    testWidgets('non-blank word taps hit the same tokens Question.words emits', (tester) async {
      // Walk through each non-blank word and verify the tap payload is
      // identical to what Question.words would produce for the same
      // phrase. If these ever drift apart the TTS cache will silently
      // miss on punctuation-attached words.
      const phrase = '¿Crees que es viejo?';
      final tokens = const Question(
        id: 0,
        phrase: phrase,
        translation: '',
        blankIndex: 1,
        answer: 'Crees',
        options: [],
      ).words;
      expect(tokens, ['¿Crees', 'que', 'es', 'viejo?']);

      final tapped = <String>[];
      await tester.pumpWidget(wrap(PhraseText(
        phrase: phrase,
        blankIndex: 1,
        answer: 'Crees',
        revealed: true,
        blankColor: Colors.green,
        textColor: Colors.white,
        onTapWord: tapped.add,
      )));

      // Tap each word (the blank is rendered as '¿Crees' after reveal).
      await tester.tap(find.textContaining('¿Crees'));
      await tester.tap(find.text('que'));
      await tester.tap(find.text('es'));
      await tester.tap(find.text('viejo?'));

      expect(tapped, tokens);
    });
  });
}
