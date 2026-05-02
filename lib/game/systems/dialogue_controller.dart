import 'dart:async';

import 'package:flame/components.dart';

import '../components/speech_bubble.dart';
import '../components/speech_messages.dart';
import '../events.dart';

/// Translates gameplay events into speech-bubble messages. Knows about
/// [SpeechMessages] so that emitters don't have to — a sibling can
/// fire `AnswerCorrect` or `IdleChatterTriggered` without understanding
/// localization or message pools.
class DialogueController extends Component {
  StreamSubscription<GameEvent>? _sub;
  final SpeechBubble _bubble;
  final GameEvents _events;
  final String Function() _localeGetter;

  DialogueController({
    required SpeechBubble bubble,
    required GameEvents events,
    required String Function() localeGetter,
  })  : _bubble = bubble,
        _events = events,
        _localeGetter = localeGetter;

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    final locale = _localeGetter();
    switch (event) {
      case AnswerCorrect(:final streak, :final answer):
        final msg = SpeechMessages.pickCorrectMessage(
          streak,
          answer,
          locale: locale,
        );
        if (msg != null) _bubble.show(msg);
      case AnswerWrong():
        final msg = SpeechMessages.pickWrongMessage(locale: locale);
        if (msg != null) _bubble.show(msg);
      case IdleChatterTriggered():
        _bubble.show(SpeechMessages.pickIdleMessage(locale: locale));
      default:
        break;
    }
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }
}
