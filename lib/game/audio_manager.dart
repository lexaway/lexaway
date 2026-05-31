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

  // UI taps confirm an action but shouldn't stomp speech, so they bow out
  // under TTS like feedback SFX but sit a touch lower.
  static const double _uiGain = 0.6;

  // Random-variant pools.
  static const List<String> _uiClicks = [
    'ui_click_1.wav',
    'ui_click_2.wav',
    'ui_click_3.wav',
    'ui_click_4.wav',
    'ui_click_5.wav',
  ];
  static const List<String> _clawClinks = [
    'claw_clink_1.wav',
    'claw_clink_2.wav',
    'claw_clink_3.wav',
    'claw_clink_4.wav',
  ];
  static const List<String> _voices = [
    'voice_1.wav',
    'voice_2.wav',
    'voice_3.wav',
    'voice_4.wav',
    'voice_5.wav',
    'voice_6.wav',
    'voice_7.wav',
    'voice_8.wav',
    'voice_9.wav',
    'voice_10.wav',
  ];
  static const List<String> _creatureFlee = [
    'creature_flee_1.wav',
    'creature_flee_2.wav',
  ];

  final _rng = Random();

  double masterVolume = 1.0;
  double sfxVolume = 1.0;

  bool _ttsDucking = false;
  set ttsDucking(bool ducking) => _ttsDucking = ducking;

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

  // UI/claw taps: present but polite — duck under TTS like feedback.
  double get _uiVol =>
      (taperedVolume(masterVolume) *
              taperedVolume(sfxVolume) *
              _uiGain *
              (_ttsDucking ? _feedbackDuck : 1.0))
          .clamp(0.0, 1.0);

  // Celebratory jingles / idle voices fire when TTS isn't speaking the
  // question, so they ring out at full volume without ducking.
  double get _jingleVol =>
      (taperedVolume(masterVolume) * taperedVolume(sfxVolume)).clamp(0.0, 1.0);

  void _playRandom(List<String> files, {required double volume}) {
    if (files.isEmpty || volume <= 0.0) return;
    FlameAudio.play(files[_rng.nextInt(files.length)], volume: volume);
  }

  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll([
      'correct.wav',
      'wrong.wav',
      for (final t in Terrain.values)
        for (var i = 1; i <= 3; i++) 'step_${t.name}_$i.wav',
      'streak.wav',
      'powerup.wav',
      'milestone.wav',
      'coin.wav',
      'gem.wav',
      'egg_crack.wav',
      'hatch_chime.wav',
      // Frequent UI taps — preloaded so the first tap has no decode hitch.
      'ui_tap.wav',
      'ui_confirm.wav',
      ..._uiClicks,
      'ui_toggle.wav',
      'ui_switch.wav',
    ]);
  }

  /// Claw-encounter SFX. Warmed when the dino reaches a cabinet rather than at
  /// boot — they're only needed inside an encounter, so they shouldn't gate
  /// world load. Idempotent: the cache no-ops on already-loaded files.
  Future<void> preloadClawSfx() => FlameAudio.audioCache.loadAll([
        'claw_prompt.wav',
        'claw_decline.wav',
        'claw_zoom_in.wav',
        'claw_zoom_out.wav',
        'claw_drop_btn.wav',
        'claw_prize_drop.wav',
        'claw_shell_crack.wav',
        ..._clawClinks,
        'jingle_win.wav',
        'jingle_lose.wav',
        'jingle_unlock.wav',
      ]);

  void playCorrect() => FlameAudio.play('correct.wav', volume: _feedbackVol);

  void playWrong() => FlameAudio.play('wrong.wav', volume: _feedbackVol);

  void playFootstep({Terrain terrain = Terrain.grass}) {
    _playRandom(
      [for (var i = 1; i <= 3; i++) 'step_${terrain.name}_$i.wav'],
      volume: _footstepVol,
    );
  }

  void playStreak() => FlameAudio.play('streak.wav', volume: _feedbackVol);

  void playPowerUp() => FlameAudio.play('powerup.wav', volume: _feedbackVol);

  void playMilestone() => FlameAudio.play('milestone.wav', volume: _feedbackVol);

  void playCoin() => FlameAudio.play('coin.wav', volume: _feedbackVol);

  void playGem() => FlameAudio.play('gem.wav', volume: _feedbackVol);

  void playEggCrack() =>
      FlameAudio.play('egg_crack.wav', volume: _feedbackVol * _eggCrackGain);

  void playHatchChime() =>
      FlameAudio.play('hatch_chime.wav', volume: _feedbackVol);

  // --- UI taps (duck under TTS) ---
  void playUiTap() => FlameAudio.play('ui_tap.wav', volume: _uiVol);
  void playUiConfirm() => FlameAudio.play('ui_confirm.wav', volume: _uiVol);
  void playUiClick() => _playRandom(_uiClicks, volume: _uiVol);
  void playToggle() => FlameAudio.play('ui_toggle.wav', volume: _uiVol);
  void playSwitch() => FlameAudio.play('ui_switch.wav', volume: _uiVol);
  void playUiError() => FlameAudio.play('ui_error.wav', volume: _uiVol);
  void playSheetOpen() => FlameAudio.play('sheet_open.wav', volume: _uiVol);
  void playSheetClose() => FlameAudio.play('sheet_close.wav', volume: _uiVol);
  void playEggTap() => FlameAudio.play('egg_tap.wav', volume: _uiVol);
  void playEggWobble() => FlameAudio.play('egg_wobble.wav', volume: _uiVol);

  // --- Claw machine (duck under TTS) ---
  void playClawPrompt() => FlameAudio.play('claw_prompt.wav', volume: _uiVol);
  void playClawDecline() => FlameAudio.play('claw_decline.wav', volume: _uiVol);
  void playClawZoomIn() => FlameAudio.play('claw_zoom_in.wav', volume: _uiVol);
  void playClawZoomOut() => FlameAudio.play('claw_zoom_out.wav', volume: _uiVol);
  void playClawDropButton() =>
      FlameAudio.play('claw_drop_btn.wav', volume: _uiVol);
  void playClawPrizeDrop() =>
      FlameAudio.play('claw_prize_drop.wav', volume: _uiVol);
  void playClawShellCrack() =>
      FlameAudio.play('claw_shell_crack.wav', volume: _uiVol);
  void playClawClink() => _playRandom(_clawClinks, volume: _uiVol);

  // --- Jingles / voice (no TTS duck) ---
  void playJingleWin() => FlameAudio.play('jingle_win.wav', volume: _jingleVol);
  void playJingleLose() =>
      FlameAudio.play('jingle_lose.wav', volume: _jingleVol);
  void playUnlockJingle() =>
      FlameAudio.play('jingle_unlock.wav', volume: _jingleVol);
  void playVoice() => _playRandom(_voices, volume: _jingleVol);

  // --- Ambient game-world one-shots (footstep tier) ---
  void playCreatureFlee() => _playRandom(_creatureFlee, volume: _footstepVol);
  void playFidgetHop() =>
      FlameAudio.play('fidget_hop.wav', volume: _footstepVol);
}
