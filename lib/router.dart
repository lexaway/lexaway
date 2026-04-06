import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/game_screen.dart';
import 'screens/pack_manager_screen.dart';

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

      if (isLoading) return loc == '/loading' ? null : '/loading';
      if (loc == '/loading') return hasQuestions ? '/game' : '/packs';
      if (!hasQuestions && loc == '/game') return '/packs';

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/packs',
        builder: (context, state) => const PackManagerScreen(),
      ),
    ],
  );
});

class _RefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
