import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'providers.dart';
import 'screens/game_screen.dart';
import 'screens/pack_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  final box = await Hive.openBox('app');

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
    final activePack = ref.watch(activePackProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.pixelifySansTextTheme(),
      ),
      home: activePack.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const PackManagerScreen(),
        data: (questions) => questions.isEmpty
            ? const PackManagerScreen()
            : GameScreen(questions: questions),
      ),
    );
  }
}
