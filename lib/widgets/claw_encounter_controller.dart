import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collectibles/collectible.dart';
import '../game/audio_manager.dart';
import '../game/events.dart';
import '../game/lexaway_game.dart';
import '../providers.dart';

/// Free to play in debug builds (handy while iterating on the art); costs
/// coins in release. kDebugMode is a compile-time const, so this stays const.
const int clawMachineCoinCost = kDebugMode ? 0 : 100;

enum ClawEncounterPhase { none, prompt, miniGame, result }

/// Immutable snapshot of the encounter flow. The named constructors are the
/// only way to build one, so every phase transition carries exactly the
/// fields that phase needs — no hand-rolled resets to forget.
@immutable
class ClawEncounterState {
  final ClawEncounterPhase phase;
  /// World index of the cabinet being played; null only when idle.
  final int? machineIndex;
  final bool won;
  final int spheresWon;
  final Collectible? prize;
  /// Whether the won prize was newly added to the player's collection —
  /// drives the dialog's "New!" vs "Already in your collection" indicator.
  final bool prizeIsNew;

  const ClawEncounterState.idle() : this._(phase: ClawEncounterPhase.none);

  const ClawEncounterState.prompt(int machineIndex)
      : this._(phase: ClawEncounterPhase.prompt, machineIndex: machineIndex);

  const ClawEncounterState.miniGame(int machineIndex)
      : this._(phase: ClawEncounterPhase.miniGame, machineIndex: machineIndex);

  const ClawEncounterState.result({
    required int machineIndex,
    required bool won,
    required int spheresWon,
    required Collectible? prize,
    required bool prizeIsNew,
  }) : this._(
          phase: ClawEncounterPhase.result,
          machineIndex: machineIndex,
          won: won,
          spheresWon: spheresWon,
          prize: prize,
          prizeIsNew: prizeIsNew,
        );

  const ClawEncounterState._({
    required this.phase,
    this.machineIndex,
    this.won = false,
    this.spheresWon = 0,
    this.prize,
    this.prizeIsNew = false,
  });
}

/// Drives the claw-machine encounter for the game screen. The flow is:
/// dino bumps cabinet → [onMachineEntered] fires → walk pauses, prompt
/// appears → on accept, coins are debited and the game zooms into the
/// cabinet to run the session → session resolves → result splash shows
/// over the zoomed view → continue zooms back out and emits
/// [ClawMachineCompleted].
///
/// Like `TtsController`: owned by the screen's state, handed [ref] and an
/// [isMounted] probe so async continuations can bail after unmount.
class ClawEncounterController extends ChangeNotifier {
  final LexawayGame game;
  final WidgetRef ref;
  final bool Function() isMounted;

  ClawEncounterController({
    required this.game,
    required this.ref,
    required this.isMounted,
  });

  ClawEncounterState _state = const ClawEncounterState.idle();
  ClawEncounterState get state => _state;

  void _emit(ClawEncounterState next) {
    _state = next;
    notifyListeners();
  }

  /// Entry point, called from the [ClawMachineEntered] game event.
  void onMachineEntered(int itemIndex) {
    if (_state.phase != ClawEncounterPhase.none) return;
    // Warm the claw SFX now (fire-and-forget) so the clinks/zoom/jingles are
    // decoded by the time the player accepts and the mini-game runs.
    AudioManager.instance.preloadClawSfx();
    // Defer to a microtask: the event bus is a sync broadcast controller,
    // and pauseMovement() emits WalkStopped — re-entering emit() inside
    // its own listener throws "Controller is already firing an event".
    // Bouncing through a microtask lets the original dispatch unwind first.
    scheduleMicrotask(() {
      if (!isMounted() || _state.phase != ClawEncounterPhase.none) return;
      game.pauseMovement();
      AudioManager.instance.playClawPrompt();
      _emit(ClawEncounterState.prompt(itemIndex));
    });
  }

  void decline() {
    final index = _state.machineIndex;
    if (index == null) return;
    AudioManager.instance.playClawDecline();
    game.events.emit(ClawMachineCompleted(
      itemIndex: index,
      won: false,
      spheresWon: 0,
      coinsSpent: 0,
    ));
    game.resumeMovement();
    _emit(const ClawEncounterState.idle());
  }

  Future<void> accept({required double safeBottomInset}) =>
      _startAttempt(retry: false, safeBottomInset: safeBottomInset);

  /// Rerun the session on the same cabinet from the result dialog — no
  /// camera zoom-out/in, so the retry feels instant.
  Future<void> tryAgain() => _startAttempt(retry: true);

  Future<void> _startAttempt({
    required bool retry,
    double safeBottomInset = 0,
  }) async {
    if (ref.read(coinProvider) < clawMachineCoinCost) return;
    final index = _state.machineIndex;
    if (index == null) return;
    ref.read(coinProvider.notifier).add(-clawMachineCoinCost);
    AudioManager.instance.playUiConfirm();
    if (!retry) AudioManager.instance.playClawZoomIn();
    _emit(ClawEncounterState.miniGame(index));
    final result = retry
        ? await game.restartClawSession(index)
        : await game.startClawEncounter(index, safeBottomInset: safeBottomInset);
    if (!isMounted()) return;
    _applyResult(index, result);
  }

  /// Commit a claw attempt's outcome to encounter state and (on a win) the
  /// persistent collection. Shared between the initial Accept flow and the
  /// Try Again retry so the inventory write happens in exactly one place.
  void _applyResult(int index, ClawAttemptResult result) {
    var isNew = false;
    final prize = result.prize;
    if (result.won && prize != null) {
      isNew = ref.read(collectionProvider.notifier).add(prize.id);
    }
    // A brand-new collectible gets the bigger "unlock" sting; a repeat win
    // gets the standard win jingle; a miss gets the gentle wah-wah.
    if (result.won) {
      isNew
          ? AudioManager.instance.playUnlockJingle()
          : AudioManager.instance.playJingleWin();
    } else {
      AudioManager.instance.playJingleLose();
    }
    _emit(ClawEncounterState.result(
      machineIndex: index,
      won: result.won,
      spheresWon: result.spheresWon,
      prize: prize,
      prizeIsNew: isNew,
    ));
  }

  Future<void> continueAfterResult() async {
    final ended = _state;
    final index = ended.machineIndex;
    if (index == null) return;
    // Clear the phase first so the question panel slides back in alongside
    // the camera zoom-out (both ~600ms) instead of popping in afterward.
    // The ended state is captured locally so the completion event below
    // still references the right cabinet.
    _emit(const ClawEncounterState.idle());
    AudioManager.instance.playClawZoomOut();
    await game.endClawEncounter();
    if (!isMounted()) return;
    game.events.emit(ClawMachineCompleted(
      itemIndex: index,
      won: ended.won,
      spheresWon: ended.spheresWon,
      coinsSpent: clawMachineCoinCost,
      prizeId: ended.prize?.id,
    ));
    game.resumeMovement();
  }
}
