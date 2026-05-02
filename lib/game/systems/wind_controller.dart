import 'dart:async';

import 'package:flame/components.dart';

import '../components/wind_lines.dart';
import '../events.dart';

/// Toggles [WindLines] on and off based on whether the dino is currently
/// running. No `update()` — everything is event-driven.
class WindController extends Component {
  StreamSubscription<GameEvent>? _sub;
  final WindLines _windLines;
  final GameEvents _events;

  WindController({required WindLines windLines, required GameEvents events})
      : _windLines = windLines,
        _events = events;

  @override
  void onMount() {
    super.onMount();
    _sub = _events.on<GameEvent>().listen(_handle);
  }

  void _handle(GameEvent event) {
    switch (event) {
      case WalkStarted(:final running):
        if (running) _windLines.start();
      case WalkSpeedChanged(:final running):
        if (running) {
          _windLines.start();
        } else {
          _windLines.stop();
        }
      case WalkStopped():
        _windLines.stop();
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
