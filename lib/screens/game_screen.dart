import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_font.dart';
import '../data/day_key.dart';
import '../data/hive_keys.dart';
import '../data/lang_codes.dart';
import '../game/audio_manager.dart';
import '../game/events.dart';
import '../game/lexaway_game.dart';
import '../models/character.dart';
import '../providers.dart';
import '../widgets/claw_prompt.dart';
import '../widgets/goal_met_banner.dart';
import '../widgets/question_panel.dart';
import '../widgets/hud_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

enum _ClawEncounterPhase { none, prompt, miniGame, result }

const int _clawMachineCoinCost = 1;

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LexawayGame? _game;
  // Tracked solely so the GameWidget below can be keyed by lang. Pack
  // switches go through `AsyncLoading` on `activePackProvider`, which the
  // router redirects to /loading — so GameScreen unmounts and remounts
  // around every switch. We never see a lang change on a live GameScreen.
  String? _activeLang;
  StreamSubscription<GameEvent>? _eventSub;
  bool _goalMetBannerVisible = false;

  // Claw machine encounter state. The flow is: dino bumps cabinet →
  // ClawMachineEntered fires → walk pauses, prompt appears → on accept,
  // coin is debited and the game zooms into the cabinet to run the
  // session → session resolves → result splash shows over the zoomed
  // view → continue zooms back out and ClawMachineCompleted fires.
  _ClawEncounterPhase _clawPhase = _ClawEncounterPhase.none;
  int? _activeClawMachineIndex;
  bool _clawWon = false;
  int _clawSpheresWon = 0;

  void _maybeShowGoalMetBanner() {
    if (_goalMetBannerVisible) return;
    final box = ref.read(hiveBoxProvider);
    final shownKey = box.get(HiveKeys.goalMetShownDayKey) as String?;
    final today = todayKey();
    if (shownKey == today) return;
    box.put(HiveKeys.goalMetShownDayKey, today);
    setState(() => _goalMetBannerVisible = true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial volume sync. `ref.listen` below only fires on subsequent
    // changes (WidgetRef.listen has no `fireImmediately` flag), so seed
    // the audio singleton with the current provider values here.
    AudioManager.instance.masterVolume = ref.read(masterVolumeProvider);
    AudioManager.instance.sfxVolume = ref.read(sfxVolumeProvider);
    // If the user returns to /game with today's goal already met (e.g.
    // after a background rollover) and we haven't flashed the banner for
    // this day yet, show it once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(goalMetTodayProvider)) _maybeShowGoalMetBanner();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final lang = ref.read(activePackProvider.notifier).activeLang!;
    final dinoLocale = iso3to2[lang] ?? 'en';
    final repo = ref.read(worldStateRepositoryProvider(lang));
    final charKey = ref.read(characterProvider(lang)) ?? 'female/doux';
    final character = CharacterInfo.fromKey(charKey);

    _game = LexawayGame(
      worldStateRepository: repo,
      locale: dinoLocale,
      characterPath: character.basePath,
      fontFamily: ref.read(fontProvider).family,
    );
    _activeLang = lang;
    // Bridge game events into Riverpod notifiers. The game bus is alive as
    // soon as LexawayGame is constructed, so subscribing here (not in
    // onLoad) is safe and avoids races on very first-frame pickups.
    // One subscription, switched on the sealed event family, so there's
    // exactly one stream listener to remember to cancel.
    _eventSub = _game!.events.on<GameEvent>().listen((event) {
      switch (event) {
        case CoinCollected(:final value):
          ref.read(coinProvider.notifier).add(value);
        case StepTaken(:final count):
          ref.read(stepsProvider.notifier).add(count);
          ref.read(langStepsProvider(_activeLang!).notifier).add(count);
        case BiomeChanged(:final current):
          ref.read(bgmSchedulerProvider).onBiomeChanged(current);
        case ClawMachineEntered(:final itemIndex):
          _onClawMachineEntered(itemIndex);
        default:
          break;
      }
    });
  }

  void _onClawMachineEntered(int itemIndex) {
    if (_clawPhase != _ClawEncounterPhase.none) return;
    // Defer to a microtask: the event bus is a sync broadcast controller,
    // and pauseMovement() emits WalkStopped — re-entering emit() inside
    // its own listener throws "Controller is already firing an event".
    // Bouncing through a microtask lets the original dispatch unwind first.
    scheduleMicrotask(() {
      if (!mounted || _clawPhase != _ClawEncounterPhase.none) return;
      _game?.pauseMovement();
      setState(() {
        _activeClawMachineIndex = itemIndex;
        _clawPhase = _ClawEncounterPhase.prompt;
      });
    });
  }

  void _onClawDecline() {
    final index = _activeClawMachineIndex;
    if (index == null) return;
    _game?.events.emit(ClawMachineCompleted(
      itemIndex: index,
      won: false,
      spheresWon: 0,
      coinsSpent: 0,
    ));
    _game?.resumeMovement();
    setState(() {
      _activeClawMachineIndex = null;
      _clawPhase = _ClawEncounterPhase.none;
    });
  }

  Future<void> _onClawAccept() async {
    final balance = ref.read(coinProvider);
    if (balance < _clawMachineCoinCost) return;
    final index = _activeClawMachineIndex;
    if (index == null) return;
    ref.read(coinProvider.notifier).add(-_clawMachineCoinCost);
    setState(() {
      _clawPhase = _ClawEncounterPhase.miniGame;
    });
    final result = await _game!.startClawEncounter(
      index,
      safeBottomInset: MediaQuery.of(context).padding.bottom,
    );
    if (!mounted) return;
    setState(() {
      _clawWon = result.won;
      _clawSpheresWon = result.spheresWon;
      _clawPhase = _ClawEncounterPhase.result;
    });
  }

  Future<void> _onClawTryAgain() async {
    final balance = ref.read(coinProvider);
    if (balance < _clawMachineCoinCost) return;
    final index = _activeClawMachineIndex;
    if (index == null) return;
    ref.read(coinProvider.notifier).add(-_clawMachineCoinCost);
    setState(() {
      _clawWon = false;
      _clawSpheresWon = 0;
      _clawPhase = _ClawEncounterPhase.miniGame;
    });
    final result = await _game!.restartClawSession(index);
    if (!mounted) return;
    setState(() {
      _clawWon = result.won;
      _clawSpheresWon = result.spheresWon;
      _clawPhase = _ClawEncounterPhase.result;
    });
  }

  Future<void> _onClawResultContinue() async {
    final index = _activeClawMachineIndex;
    if (index == null) return;
    final won = _clawWon;
    final spheresWon = _clawSpheresWon;
    // Clear the phase first so the question panel slides back in alongside
    // the camera zoom-out (both ~600ms) instead of popping in afterward.
    // The encounter index is captured locally so the completion event below
    // still references the right cabinet.
    setState(() {
      _activeClawMachineIndex = null;
      _clawPhase = _ClawEncounterPhase.none;
      _clawWon = false;
      _clawSpheresWon = 0;
    });
    await _game!.endClawEncounter();
    if (!mounted) return;
    _game?.events.emit(ClawMachineCompleted(
      itemIndex: index,
      won: won,
      spheresWon: spheresWon,
      coinsSpent: _clawMachineCoinCost,
    ));
    _game?.resumeMovement();
  }

  @override
  void dispose() {
    // Lifecycle observer already flushes on pause/inactive before dispose,
    // but flush again in case of direct navigation without backgrounding.
    _flushGameState();
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushGameState();
    }
  }

  /// Best-effort save during teardown / backgrounding. Both underlying calls
  /// can throw during teardown (finishMovement touches game components that
  /// may already be detached; flushWorldState goes through Hive and could
  /// surface disk errors) — neither should escape into the Flutter framework.
  void _flushGameState() {
    final game = _game;
    if (game == null) return;
    try {
      game.finishMovement();
    } catch (_) {
      // Components already detached; fall through to flush.
    }
    try {
      game.flushWorldState();
    } catch (_) {
      // Hive write failed during teardown; nothing useful we can do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final source = ref.watch(activePackProvider).valueOrNull;

    // Forward font selection changes from Settings into the running game so
    // the speech bubble updates without requiring a game rebuild.
    ref.listen<AppFont>(fontProvider, (prev, next) {
      _game?.fontFamily = next.family;
    });

    // Sync volume settings to the audio singleton (initial values are
    // seeded in initState).
    ref.listen<double>(masterVolumeProvider, (prev, next) {
      AudioManager.instance.masterVolume = next;
    });
    ref.listen<double>(sfxVolumeProvider, (prev, next) {
      AudioManager.instance.sfxVolume = next;
    });

    // Goal-met flourish: fire when a *step* pushes today across the goal
    // line. We gate on the step delta (not the derived goal-met bool) so
    // that lowering the daily goal from Settings never retroactively
    // triggers the banner. Once-per-day dedup lives in the shown-key check.
    ref.listen<StepsState>(stepsProvider, (prev, next) {
      if (prev == null) return;
      final goal = ref.read(dailyGoalProvider);
      if (prev.today < goal && next.today >= goal) _maybeShowGoalMetBanner();
    });

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTap: kDebugMode
                ? () {
                    game.toggleDebugWalk();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          game.debugWalk
                              ? '🦕 Debug walk ON — strolling forever'
                              : '🦕 Debug walk OFF',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                : null,
            child: GameWidget(key: ValueKey(_activeLang), game: game),
          ),
          Positioned(left: 0, right: 0, top: 0, child: const HudBar()),
          if (source != null)
            Positioned(
              left: 0,
              right: 0,
              top:
                  MediaQuery.of(context).size.height * LexawayGame.groundLevel +
                  64,
              bottom: -24,
              // Slide the panel off-screen during a claw encounter so the
              // cabinet has the full viewport. State stays mounted (selected
              // option, shake animation, TTS prefetch) so the dino picks up
              // exactly where it left off when the encounter ends.
              child: AnimatedSlide(
                offset: _clawPhase == _ClawEncounterPhase.none ||
                        _clawPhase == _ClawEncounterPhase.prompt
                    ? Offset.zero
                    : const Offset(0, 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _clawPhase != _ClawEncounterPhase.none,
                  child: QuestionPanel(
                    key: ValueKey(source),
                    game: game,
                    source: source,
                  ),
                ),
              ),
            ),
          if (_goalMetBannerVisible)
            GoalMetBanner(
              onDismissed: () {
                if (mounted) setState(() => _goalMetBannerVisible = false);
              },
            ),
          if (_clawPhase == _ClawEncounterPhase.prompt)
            Positioned.fill(
              child: ClawPrompt(
                coinCost: _clawMachineCoinCost,
                currentCoins: ref.watch(coinProvider),
                onAccept: _onClawAccept,
                onDecline: _onClawDecline,
              ),
            ),
          if (_clawPhase == _ClawEncounterPhase.result)
            Positioned.fill(
              child: _ClawResultDialog(
                won: _clawWon,
                tryAgainCost: _clawMachineCoinCost,
                canAffordTryAgain:
                    ref.watch(coinProvider) >= _clawMachineCoinCost,
                onContinue: _onClawResultContinue,
                onTryAgain: _onClawTryAgain,
              ),
            ),
        ],
      ),
    );
  }
}

/// Result splash shown over the zoomed-in cabinet after the session
/// resolves. Continue tap zooms the camera back out.
class _ClawResultDialog extends StatelessWidget {
  final bool won;
  final int tryAgainCost;
  final bool canAffordTryAgain;
  final VoidCallback onContinue;
  final VoidCallback onTryAgain;

  const _ClawResultDialog({
    required this.won,
    required this.tryAgainCost,
    required this.canAffordTryAgain,
    required this.onContinue,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0AC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC2185B), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'You got a sphere!' : 'So close!',
                style: const TextStyle(
                  fontFamily: 'Pixelify Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC2185B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                won ? '+1 sphere' : 'Try the next one.',
                style: const TextStyle(
                  fontFamily: 'Pixelify Sans',
                  fontSize: 16,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onContinue,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC2185B),
                      side: const BorderSide(
                        color: Color(0xFFC2185B),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: 'Pixelify Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canAffordTryAgain ? onTryAgain : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD8B4A0),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Try again (${tryAgainCost}c)',
                      style: const TextStyle(
                        fontFamily: 'Pixelify Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
