class Question {
  final String phrase;
  final String translation;
  final String answer;
  final List<String> options;

  const Question({
    required this.phrase,
    required this.translation,
    required this.answer,
    required this.options,
  });

  String get displayPhrase => phrase.replaceFirst(answer, '____');
}

const mockQuestions = [
  Question(
    phrase: 'Je voudrais un café, s\'il vous plaît.',
    translation: 'I would like a coffee, please.',
    answer: 'voudrais',
    options: ['voudrais', 'mange', 'donne'],
  ),
  Question(
    phrase: 'Elle mange une pomme rouge.',
    translation: 'She is eating a red apple.',
    answer: 'mange',
    options: ['mange', 'boit', 'dort'],
  ),
  Question(
    phrase: 'Nous allons à la plage demain.',
    translation: 'We are going to the beach tomorrow.',
    answer: 'allons',
    options: ['venons', 'allons', 'partons'],
  ),
  Question(
    phrase: 'Il fait très froid en hiver.',
    translation: 'It is very cold in winter.',
    answer: 'froid',
    options: ['chaud', 'beau', 'froid'],
  ),
  Question(
    phrase: 'Tu peux ouvrir la fenêtre?',
    translation: 'Can you open the window?',
    answer: 'ouvrir',
    options: ['fermer', 'ouvrir', 'casser'],
  ),
  Question(
    phrase: 'Les enfants jouent dans le jardin.',
    translation: 'The children are playing in the garden.',
    answer: 'jouent',
    options: ['dorment', 'jouent', 'courent'],
  ),
  Question(
    phrase: 'Je cherche la gare, s\'il vous plaît.',
    translation: 'I am looking for the train station, please.',
    answer: 'cherche',
    options: ['trouve', 'cherche', 'connais'],
  ),
  Question(
    phrase: 'Mon frère habite à Paris depuis cinq ans.',
    translation: 'My brother has lived in Paris for five years.',
    answer: 'habite',
    options: ['travaille', 'habite', 'voyage'],
  ),
  Question(
    phrase: 'Elle porte une belle robe bleue.',
    translation: 'She is wearing a beautiful blue dress.',
    answer: 'belle',
    options: ['grande', 'belle', 'vieille'],
  ),
  Question(
    phrase: 'Nous avons besoin de lait.',
    translation: 'We need milk.',
    answer: 'besoin',
    options: ['envie', 'peur', 'besoin'],
  ),
];
