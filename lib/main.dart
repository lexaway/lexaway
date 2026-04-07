import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'data/hive_keys.dart';
import 'providers.dart';
import 'router.dart';

/// Current Hive box schema version. Bump when the shape of stored data changes
/// and add a migration case in _migrateHive.
const hiveSchemaVersion = 1;

void _migrateHive(Box box) {
  final old = box.get(HiveKeys.hiveSchemaVersion, defaultValue: 0) as int;
  if (old >= hiveSchemaVersion) return;

  // --- future migrations go here ---
  // if (old < 2) { ... }

  box.put(HiveKeys.hiveSchemaVersion, hiveSchemaVersion);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  final box = await Hive.openBox('app');
  _migrateHive(box);

  runApp(
    ProviderScope(
      overrides: [hiveBoxProvider.overrideWithValue(box)],
      child: const LexawayApp(),
    ),
  );
}

class LexawayApp extends ConsumerWidget {
  const LexawayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(textTheme: GoogleFonts.pixelifySansTextTheme()),
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
