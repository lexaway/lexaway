import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/egg_selection_screen.dart';
import 'screens/game_screen.dart';
import 'screens/pack_manager_screen.dart';
import 'screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RefreshNotifier();
  ref.listen(activePackProvider, (_, __) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final activePack = ref.read(activePackProvider);
      final isLoading = activePack.isLoading;
      final hasQuestions = activePack.valueOrNull?.isNotEmpty ?? false;
      final loc = state.matchedLocation;
      final box = ref.read(hiveBoxProvider);

      // Settings and packs are always reachable, even while loading
      if (loc == '/settings' || loc == '/packs') return null;

      if (isLoading) return loc == '/loading' ? null : '/loading';

      if (loc == '/loading') {
        if (!hasQuestions) return '/packs';
        final lang = ref.read(activePackProvider.notifier).activeLang;
        final hasChar = lang != null && box.get('character_$lang') != null;
        return hasChar ? '/game' : '/hatch';
      }

      if (!hasQuestions && (loc == '/game' || loc == '/hatch')) return '/packs';

      if (loc == '/game') {
        final lang = ref.read(activePackProvider.notifier).activeLang;
        final hasChar = lang != null && box.get('character_$lang') != null;
        if (!hasChar) return '/hatch';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/hatch',
        builder: (context, state) => const EggSelectionScreen(),
      ),
      GoRoute(path: '/game', builder: (context, state) => const GameScreen()),
      GoRoute(
        path: '/packs',
        builder: (context, state) => const PackManagerScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class _RefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
