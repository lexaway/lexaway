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
import '../widgets/goal_met_banner.dart';
import '../widgets/question_panel.dart';
import '../widgets/hud_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LexawayGame? _game;
  StreamSubscription<GameEvent>? _eventSub;
  bool _goalMetBannerVisible = false;

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
    final lang = ref.read(activePackProvider.notifier).activeLang!;
    final dinoLocale = iso3to2[lang] ?? 'en';
    if (_game == null) {
      final repo = ref.read(worldStateRepositoryProvider);
      final charKey = ref.read(characterProvider(lang)) ?? 'female/doux';
      final character = CharacterInfo.fromKey(charKey);

      _game = LexawayGame(
        worldStateRepository: repo,
        locale: dinoLocale,
        characterPath: character.basePath,
        fontFamily: ref.read(fontProvider).family,
      );
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
          case BiomeChanged():
            ref.read(bgmSchedulerProvider).onBiomeChanged();
          default:
            break;
        }
      });
    } else {
      _game!.locale = dinoLocale;
    }
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
      game.movementController.finishMovement();
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
            child: GameWidget(game: game),
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
              child: QuestionPanel(
                key: ValueKey(source),
                game: game,
                source: source,
              ),
            ),
          if (_goalMetBannerVisible)
            GoalMetBanner(
              onDismissed: () {
                if (mounted) setState(() => _goalMetBannerVisible = false);
              },
            ),
        ],
      ),
    );
  }
}
