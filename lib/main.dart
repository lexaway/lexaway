import 'dart:async';

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

class _LexawayAppState extends ConsumerState<LexawayApp> {
  @override
  void initState() {
    super.initState();
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
