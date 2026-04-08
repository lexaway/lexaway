import 'dart:math';

import 'package:flame_audio/flame_audio.dart';

enum Terrain { grass, dirt, snow }

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  static AudioManager get instance => _instance;
  AudioManager._();

  final _rng = Random();

  double masterVolume = 1.0;
  double sfxVolume = 1.0;

  double get _vol => (masterVolume * sfxVolume).clamp(0.0, 1.0);

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

  void playCorrect() => FlameAudio.play('correct.wav', volume: _vol);

  void playWrong() => FlameAudio.play('wrong.wav', volume: _vol);

  void playFootstep({Terrain terrain = Terrain.grass}) {
    final n = _rng.nextInt(3) + 1;
    FlameAudio.play('step_${terrain.name}_$n.wav', volume: _vol);
  }

  void playStreak() => FlameAudio.play('streak.wav', volume: _vol);

  void playCoin() => FlameAudio.play('coin.wav', volume: _vol);

  void playGem() => FlameAudio.play('gem.wav', volume: _vol);
}
