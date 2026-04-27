import 'dart:math';

import 'package:flame_audio/flame_audio.dart';

import '../data/volume_taper.dart';

enum Terrain { grass, dirt, snow }

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  static AudioManager get instance => _instance;
  AudioManager._();

  // Feedback SFX confirm user actions, so they stay audible under TTS.
  // Footsteps are pure ambience and disappear so speech wins cleanly.
  static const double _feedbackDuck = 0.5;
  static const double _footstepDuck = 0.0;

  // Footsteps sit under feedback SFX so the ambient layer doesn't compete
  // with confirmations.
  static const double _footstepGain = 0.35;

  // Egg crack is a soft squelch, not an event marker — quieter than the
  // other feedback hits.
  static const double _eggCrackGain = 0.4;

  final _rng = Random();

  double masterVolume = 1.0;
  double sfxVolume = 1.0;

  bool _ttsDucking = false;
  void setTtsDucking(bool ducking) => _ttsDucking = ducking;

  double get _feedbackVol =>
      (taperedVolume(masterVolume) *
              taperedVolume(sfxVolume) *
              (_ttsDucking ? _feedbackDuck : 1.0))
          .clamp(0.0, 1.0);

  double get _footstepVol => _ttsDucking
      ? _footstepDuck
      : (taperedVolume(masterVolume) *
                taperedVolume(sfxVolume) *
                _footstepGain)
            .clamp(0.0, 1.0);

  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll([
      'correct.wav',
      'wrong.wav',
      for (final t in Terrain.values)
        for (var i = 1; i <= 3; i++) 'step_${t.name}_$i.wav',
      'streak.wav',
      'coin.wav',
      'gem.wav',
      'crunch_crunchy.wav',
      'hatch_chime.wav',
    ]);
  }

  void playCorrect() => FlameAudio.play('correct.wav', volume: _feedbackVol);

  void playWrong() => FlameAudio.play('wrong.wav', volume: _feedbackVol);

  void playFootstep({Terrain terrain = Terrain.grass}) {
    final vol = _footstepVol;
    if (vol <= 0.0) return;
    final n = _rng.nextInt(3) + 1;
    FlameAudio.play('step_${terrain.name}_$n.wav', volume: vol);
  }

  void playStreak() => FlameAudio.play('streak.wav', volume: _feedbackVol);

  void playCoin() => FlameAudio.play('coin.wav', volume: _feedbackVol);

  void playGem() => FlameAudio.play('gem.wav', volume: _feedbackVol);

  void playEggCrack() =>
      FlameAudio.play('crunch_crunchy.wav', volume: _feedbackVol * _eggCrackGain);

  void playHatchChime() =>
      FlameAudio.play('hatch_chime.wav', volume: _feedbackVol);
}
