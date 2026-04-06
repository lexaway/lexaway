import 'dart:math';

import 'package:flame_audio/flame_audio.dart';

enum Terrain { grass, dirt, snow }

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  static AudioManager get instance => _instance;
  AudioManager._();

  final _rng = Random();

  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll([
      'correct.wav',
      'wrong.wav',
      for (final t in Terrain.values)
        for (var i = 1; i <= 3; i++) 'step_${t.name}_$i.wav',
      'streak.wav',
      'coin.wav',
      'gem.wav',
    ]);
  }

  void playCorrect() => FlameAudio.play('correct.wav');

  void playWrong() => FlameAudio.play('wrong.wav');

  void playFootstep() {
    final n = _rng.nextInt(3) + 1;
    FlameAudio.play('step_${Terrain.grass.name}_$n.wav');
  }

  void playStreak() => FlameAudio.play('streak.wav');

  void playCoin() => FlameAudio.play('coin.wav');

  void playGem() => FlameAudio.play('gem.wav');
}
