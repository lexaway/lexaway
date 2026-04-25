import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'data/day_key.dart';
import 'data/hive_keys.dart';
import 'providers.dart';
import 'router.dart';
import 'services/reminder_service.dart';

/// Current Hive box schema version. Bump when the shape of stored data changes
/// and add a migration case in migrateHive.
const hiveSchemaVersion = 2;

void migrateHive(Box box) {
  final old = box.get(HiveKeys.hiveSchemaVersion, defaultValue: 0) as int;
  if (old >= hiveSchemaVersion) return;

  if (old < 2) {
    // v1 → v2: split lifetime 'steps' int into daily-aware triple.
    final legacyLifetime = box.get('steps', defaultValue: 0) as int;
    box.put(HiveKeys.stepsLifetime, legacyLifetime);
    box.put(HiveKeys.stepsToday, 0);
    box.put(HiveKeys.stepsDayKey, todayKey());
    box.delete('steps');
  }

  box.put(HiveKeys.hiveSchemaVersion, hiveSchemaVersion);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final docsDir = await getApplicationDocumentsDirectory();
  final supportDir = await getApplicationSupportDirectory();
  final tmpDir = await getTemporaryDirectory();

  Hive.init(docsDir.path);
  final box = await Hive.openBox('app');
  migrateHive(box);

  // BGM and TTS each create their own AudioPlayer; without mixWithOthers,
  // iOS deactivates whichever AVAudioSession was active when a new one
  // activates — so TTS's first utterance would kill BGM. `playback` plays
  // through the speaker even when the device is muted, which is what we
  // want for a learning app where TTS is the pedagogical payload.
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(box),
        packsDirProvider.overrideWithValue('${docsDir.path}/packs'),
        modelsDirProvider.overrideWithValue('${supportDir.path}/tts_models'),
        tmpDirProvider.overrideWithValue(tmpDir.path),
      ],
      child: const LexawayApp(),
    ),
  );
}

class LexawayApp extends ConsumerStatefulWidget {
  const LexawayApp({super.key});

  @override
  ConsumerState<LexawayApp> createState() => _LexawayAppState();
}

class _LexawayAppState extends ConsumerState<LexawayApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget: initialize the notifications plugin + timezone data,
    // wire the ref-driven listeners, and schedule the first reminder if
    // one is due. We don't block the UI on this — scheduling errors would
    // only affect the reminder, not app boot.
    final service = ref.read(reminderServiceProvider);
    unawaited(
      service.init().then((_) {
        service.attachListeners();
        service.scheduleNext();
      }).catchError((Object e, StackTrace s) {
        debugPrint('[ReminderService] init failed: $e\n$s');
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bgm = ref.read(bgmServiceProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(bgm.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(bgm.resume());
      // Dart timers don't fire while the app is suspended, so a multi-hour
      // background nap would leave us still queued for the old hour's track.
      // Re-arming on resume snaps us back to the current hour.
      ref.read(bgmSchedulerProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    final locale = ref.watch(localeProvider);
    final font = ref.watch(fontProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: font.family),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        for (final s in supported) {
          if (s.languageCode == deviceLocale?.languageCode) return s;
        }
        return const Locale('en');
      },
      routerConfig: router,
    );
  }
}
