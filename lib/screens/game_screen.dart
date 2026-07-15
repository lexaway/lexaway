import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show AssetSource;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_font.dart';
import '../data/lang_codes.dart';
import '../game/events.dart';
import '../game/lexaway_game.dart';
import '../game/world/biome_registry.dart';
import '../game/world/world_map.dart';
import '../models/character.dart';
import '../providers.dart';
import '../widgets/claw_encounter_controller.dart';
import '../widgets/claw_prompt.dart';
import '../widgets/claw_result_dialog.dart';
import '../widgets/hud_bar.dart';
import '../widgets/question_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LexawayGame? _game;
  // Tracked solely so the GameWidget below can be keyed by lang. Pack
  // switches go through `AsyncLoading` on `activePackProvider`, which the
  // router redirects to /loading — so GameScreen unmounts and remounts
  // around every switch. We never see a lang change on a live GameScreen.
  String? _activeLang;
  StreamSubscription<GameEvent>? _eventSub;
  ClawEncounterController? _claw;

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
    _claw = ClawEncounterController(
      game: _game!,
      ref: ref,
      isMounted: () => mounted,
    )..addListener(_onClawChanged);
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
          _applyAmbient(current);
        case ClawMachineEntered(:final itemIndex):
          _claw!.onMachineEntered(itemIndex);
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

    // The starting biome never emits BiomeChanged, so kick its ambient bed
    // once the world is loaded and the screen-centre probe is meaningful.
    _game!.loaded.then((_) {
      if (mounted) _applyAmbient(_game!.currentBiome);
    });
  }

  /// The claw controller owns the encounter state; the screen just re-renders
  /// the overlay stack whenever a phase transition lands.
  void _onClawChanged() => setState(() {});

  /// Start, swap, or stop the looping ambient bed for [biome]. Beds are
  /// declared per-biome on `BiomeDefinition.ambientLoop`; a null one means
  /// silence (the player crossfades out).
  void _applyAmbient(BiomeType biome) {
    final loop = BiomeRegistry.get(biome).ambientLoop;
    final svc = ref.read(ambientServiceProvider);
    if (loop == null) {
      svc.stop();
    } else {
      svc.playLoop('ambient/$loop', AssetSource(loop));
    }
  }

  @override
  void dispose() {
    // Lifecycle observer already flushes on pause/inactive before dispose,
    // but flush again in case of direct navigation without backgrounding.
    _flushGameState();
    _eventSub?.cancel();
    _claw?.dispose();
    // Ambient is gameplay-only — silence the bed on the way out (BGM keeps
    // playing menu music via the route observer).
    ref.read(ambientServiceProvider).stop();
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
    final claw = _claw!.state;
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
                  MediaQuery.sizeOf(context).height * LexawayGame.groundLevel +
                  64,
              bottom: -24,
              // Slide the panel off-screen during a claw encounter so the
              // cabinet has the full viewport. State stays mounted (selected
              // option, shake animation, TTS prefetch) so the dino picks up
              // exactly where it left off when the encounter ends.
              child: AnimatedSlide(
                offset: claw.phase == ClawEncounterPhase.none ||
                        claw.phase == ClawEncounterPhase.prompt
                    ? Offset.zero
                    : const Offset(0, 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: claw.phase != ClawEncounterPhase.none,
                  child: QuestionPanel(
                    key: ValueKey(source),
                    game: game,
                    source: source,
                  ),
                ),
              ),
            ),
          if (claw.phase == ClawEncounterPhase.prompt)
            Positioned.fill(
              child: ClawPrompt(
                coinCost: clawMachineCoinCost,
                currentCoins: ref.watch(coinProvider),
                onAccept: () => _claw!.accept(
                  safeBottomInset: MediaQuery.paddingOf(context).bottom,
                ),
                onDecline: _claw!.decline,
              ),
            ),
          if (claw.phase == ClawEncounterPhase.result)
            Positioned.fill(
              child: ClawResultDialog(
                won: claw.won,
                prize: claw.prize,
                isNewPrize: claw.prizeIsNew,
                tryAgainCost: clawMachineCoinCost,
                canAffordTryAgain:
                    ref.watch(coinProvider) >= clawMachineCoinCost,
                onContinue: _claw!.continueAfterResult,
                onTryAgain: _claw!.tryAgain,
              ),
            ),
        ],
      ),
    );
  }
}
