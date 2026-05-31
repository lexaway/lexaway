import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_font.dart';
import '../data/collectibles/collectible.dart';
import '../data/collectibles/registry.dart';
import '../data/lang_codes.dart';
import '../game/audio_manager.dart';
import '../game/claw_machine/prize_sphere.dart';
import '../game/events.dart';
import '../game/lexaway_game.dart';
import '../l10n/app_localizations.dart';
import '../models/character.dart';
import '../providers.dart';
import '../widgets/claw_prompt.dart';
import '../widgets/hud_bar.dart';
import '../widgets/question_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

enum _ClawEncounterPhase { none, prompt, miniGame, result }

// Free to play in debug builds (handy while iterating on the art); costs
// coins in release. kDebugMode is a compile-time const, so this stays const.
const int _clawMachineCoinCost = kDebugMode ? 0 : 100;

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LexawayGame? _game;
  // Tracked solely so the GameWidget below can be keyed by lang. Pack
  // switches go through `AsyncLoading` on `activePackProvider`, which the
  // router redirects to /loading — so GameScreen unmounts and remounts
  // around every switch. We never see a lang change on a live GameScreen.
  String? _activeLang;
  StreamSubscription<GameEvent>? _eventSub;

  // Claw machine encounter state. The flow is: dino bumps cabinet →
  // ClawMachineEntered fires → walk pauses, prompt appears → on accept,
  // coin is debited and the game zooms into the cabinet to run the
  // session → session resolves → result splash shows over the zoomed
  // view → continue zooms back out and ClawMachineCompleted fires.
  _ClawEncounterPhase _clawPhase = _ClawEncounterPhase.none;
  int? _activeClawMachineIndex;
  bool _clawWon = false;
  int _clawSpheresWon = 0;
  Collectible? _clawPrize;
  // Whether the won prize was newly added to the player's collection — drives
  // the dialog's "New!" vs "Already in your collection" indicator.
  bool _clawPrizeIsNew = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        // Events handled elsewhere (or not at this layer) — listed explicitly
        // rather than via `default` so a new GameEvent subtype trips the
        // analyzer's exhaustiveness check here instead of being silently dropped.
        case AnswerCorrect() ||
              AnswerWrong() ||
              WalkStarted() ||
              WalkSpeedChanged() ||
              WalkStopped() ||
              IdleChatterTriggered() ||
              WorldExtended() ||
              ClawMachineCompleted():
          break;
      }
    });
  }

  void _onClawMachineEntered(int itemIndex) {
    if (_clawPhase != _ClawEncounterPhase.none) return;
    // Warm the claw SFX now (fire-and-forget) so the clinks/zoom/jingles are
    // decoded by the time the player accepts and the mini-game runs.
    AudioManager.instance.preloadClawSfx();
    // Defer to a microtask: the event bus is a sync broadcast controller,
    // and pauseMovement() emits WalkStopped — re-entering emit() inside
    // its own listener throws "Controller is already firing an event".
    // Bouncing through a microtask lets the original dispatch unwind first.
    scheduleMicrotask(() {
      if (!mounted || _clawPhase != _ClawEncounterPhase.none) return;
      _game?.pauseMovement();
      AudioManager.instance.playClawPrompt();
      setState(() {
        _activeClawMachineIndex = itemIndex;
        _clawPhase = _ClawEncounterPhase.prompt;
      });
    });
  }

  void _onClawDecline() {
    final index = _activeClawMachineIndex;
    if (index == null) return;
    AudioManager.instance.playClawDecline();
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
    AudioManager.instance.playUiConfirm();
    AudioManager.instance.playClawZoomIn();
    setState(() {
      _clawPhase = _ClawEncounterPhase.miniGame;
    });
    final result = await _game!.startClawEncounter(
      index,
      safeBottomInset: MediaQuery.of(context).padding.bottom,
    );
    if (!mounted) return;
    _applyClawResult(result);
  }

  Future<void> _onClawTryAgain() async {
    final balance = ref.read(coinProvider);
    if (balance < _clawMachineCoinCost) return;
    final index = _activeClawMachineIndex;
    if (index == null) return;
    ref.read(coinProvider.notifier).add(-_clawMachineCoinCost);
    AudioManager.instance.playUiConfirm();
    setState(() {
      _clawWon = false;
      _clawSpheresWon = 0;
      _clawPrize = null;
      _clawPrizeIsNew = false;
      _clawPhase = _ClawEncounterPhase.miniGame;
    });
    final result = await _game!.restartClawSession(index);
    if (!mounted) return;
    _applyClawResult(result);
  }

  /// Commit a claw attempt's outcome to local state and (on a win) the
  /// persistent collection. Shared between the initial Accept flow and the
  /// Try Again retry so the inventory write happens in exactly one place.
  void _applyClawResult(ClawAttemptResult result) {
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
    setState(() {
      _clawWon = result.won;
      _clawSpheresWon = result.spheresWon;
      _clawPrize = prize;
      _clawPrizeIsNew = isNew;
      _clawPhase = _ClawEncounterPhase.result;
    });
  }

  Future<void> _onClawResultContinue() async {
    final index = _activeClawMachineIndex;
    if (index == null) return;
    final won = _clawWon;
    final spheresWon = _clawSpheresWon;
    final prizeId = _clawPrize?.id;
    // Clear the phase first so the question panel slides back in alongside
    // the camera zoom-out (both ~600ms) instead of popping in afterward.
    // The encounter index is captured locally so the completion event below
    // still references the right cabinet.
    setState(() {
      _activeClawMachineIndex = null;
      _clawPhase = _ClawEncounterPhase.none;
      _clawWon = false;
      _clawSpheresWon = 0;
      _clawPrize = null;
      _clawPrizeIsNew = false;
    });
    AudioManager.instance.playClawZoomOut();
    await _game!.endClawEncounter();
    if (!mounted) return;
    _game?.events.emit(ClawMachineCompleted(
      itemIndex: index,
      won: won,
      spheresWon: spheresWon,
      coinsSpent: _clawMachineCoinCost,
      prizeId: prizeId,
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
          const Positioned(left: 0, right: 0, top: 0, child: HudBar()),
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
                prize: _clawPrize,
                isNewPrize: _clawPrizeIsNew,
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
  final Collectible? prize;
  final bool isNewPrize;
  final int tryAgainCost;
  final bool canAffordTryAgain;
  final VoidCallback onContinue;
  final VoidCallback onTryAgain;

  const _ClawResultDialog({
    required this.won,
    required this.prize,
    required this.isNewPrize,
    required this.tryAgainCost,
    required this.canAffordTryAgain,
    required this.onContinue,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              if (won && prize != null) ...[
                _PrizePreview(collectible: prize!),
                const SizedBox(height: 12),
                Text(
                  prize!.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isNewPrize ? l10n.clawPrizeNew : l10n.clawPrizeOwned,
                  style: TextStyle(
                    fontSize: 14,
                    color: isNewPrize
                        ? const Color(0xFFC2185B)
                        : const Color(0xFF8D6E63),
                  ),
                ),
              ] else ...[
                // Every claw sphere carries a flag, so a win always has a
                // prize and lands in the branch above — this branch is the
                // loss case.
                Text(
                  l10n.clawLost,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC2185B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.clawLostDetail,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
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
                    child: Text(
                      l10n.continueLabel,
                      style: const TextStyle(
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
                      l10n.clawTryAgain(tryAgainCost),
                      style: const TextStyle(
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

/// Big two-tone sphere preview for the result dialog. Composes the shell +
/// sprite into a small offscreen image and renders it with `RawImage` at
/// `FilterQuality.none`, so the preview matches the chunky in-game ball.
class _PrizePreview extends StatefulWidget {
  final Collectible collectible;
  const _PrizePreview({required this.collectible});

  @override
  State<_PrizePreview> createState() => _PrizePreviewState();
}

class _PrizePreviewState extends State<_PrizePreview>
    with SingleTickerProviderStateMixin {
  static const Duration _crackDelay = Duration(milliseconds: 450);
  static const Duration _crackDuration = Duration(milliseconds: 650);
  static const double _previewSize = 96;

  PrizeSphereLayers? _layers;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _crackDuration);

    // A stable shell color so the same dialog frame doesn't flicker if it
    // rebuilds mid-animation. Index off the collectible id so two retries
    // landing on the same prize get the same shell.
    final shell = shellPalette[
        widget.collectible.id.codeUnits.fold(0, (a, b) => a + b) %
            shellPalette.length];
    () async {
      final assetPath = widget.collectible.spriteAsset;
      final sprite = CollectibleRegistry.instance.cachedSprite(assetPath) ??
          await CollectibleRegistry.instance.loadSprite(assetPath);
      final layers = await composePrizeSphereLayers(
        sprite: sprite,
        shellLeft: shell.$1,
        shellRight: shell.$2,
      );
      if (!mounted) return;
      setState(() => _layers = layers);
      // Brief beat so the user registers the closed shell before it cracks.
      await Future<void>.delayed(_crackDelay);
      if (!mounted) return;
      AudioManager.instance.playClawShellCrack();
      _ctrl.forward();
    }();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    if (layers == null) {
      return const SizedBox(width: _previewSize, height: _previewSize);
    }
    return SizedBox(
      width: _previewSize,
      height: _previewSize,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // easeOut so the halves swing open fast at first, then settle.
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          // Hinge at the bottom-center: rotate the top edge of each half
          // outward (clamshell opening). A bit past 90° so the halves
          // overshoot horizontal before falling.
          final angle = t * (math.pi / 2 + 0.25);
          // Once the halves are mostly open, let them drift down and fade
          // out — looks like the shell pieces tumble off the prize.
          final fadeT = ((t - 0.5) * 2).clamp(0.0, 1.0);
          final shellAlpha = 1 - fadeT;
          final drop = _previewSize * 0.35 * fadeT * fadeT;
          // The sprite occupies the same fraction of the sphere as it
          // does inside [paintPrizeSphere]: width = `radius * innerScale`
          // in sphere-pixel space, so divide by the full diameter
          // (pixelSize) to get the screen-space ratio. Sizing the
          // SizedBox to this fraction and rendering the raw sprite gives
          // a single clean upscale from the source PNG to screen.
          final radius = layers.pixelSize / 2 - 0.5;
          final innerFraction =
              (radius * layers.innerScale) / layers.pixelSize;
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: FractionallySizedBox(
                  widthFactor: innerFraction,
                  child: AspectRatio(
                    aspectRatio:
                        layers.sprite.width / layers.sprite.height,
                    child: RawImage(
                      image: layers.sprite,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      isAntiAlias: false,
                    ),
                  ),
                ),
              ),
              _ShellHalf(
                image: layers.leftHalf,
                angle: -angle,
                drop: drop,
                opacity: shellAlpha,
              ),
              _ShellHalf(
                image: layers.rightHalf,
                angle: angle,
                drop: drop,
                opacity: shellAlpha,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One half of the cracking shell: rotates around its own bottom-center
/// (the seam where the two halves meet) and optionally drops + fades as
/// it falls away.
class _ShellHalf extends StatelessWidget {
  final ui.Image image;
  final double angle;
  final double drop;
  final double opacity;
  const _ShellHalf({
    required this.image,
    required this.angle,
    required this.drop,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, drop),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: opacity,
          child: RawImage(
            image: image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
          ),
        ),
      ),
    );
  }
}
