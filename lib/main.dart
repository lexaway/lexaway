import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'data/hive_migration.dart';
import 'providers.dart';
import 'router.dart';

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

class LexawayApp extends ConsumerWidget {
  const LexawayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
