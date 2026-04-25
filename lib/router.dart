import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/egg_selection_screen.dart';
import 'screens/game_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/pack_manager_screen.dart';
import 'screens/attributions_screen.dart';
import 'screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RefreshNotifier();
  // Always notify — the redirect is idempotent and handles all states.
  ref.listen(activePackProvider, (_, __) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  // Watch route changes — including imperative `context.push(...)` calls,
  // which don't fire the routerDelegate listener — and switch BGM mode
  // accordingly. /game runs random gameplay tracks, everything else runs
  // the main theme.
  final bgmObserver = _BgmRouteObserver((name) {
    // /loading is a sub-second routing gate — skip it so we don't load
    // mainTheme just to immediately swap to a gameplay track.
    if (name == '/loading') return;
    final scheduler = ref.read(bgmSchedulerProvider);
    if (name == '/game') {
      scheduler.startGameplay();
    } else {
      scheduler.startMain();
    }
  });

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: refreshNotifier,
    observers: [bgmObserver],
    redirect: (context, state) {
      final activePack = ref.read(activePackProvider);
      final isLoading = activePack.isLoading;
      final hasQuestions = activePack.valueOrNull?.hasQuestions ?? false;
      final loc = state.matchedLocation;

      // Settings, attributions, and packs are always reachable, even while loading
      if (loc == '/settings' || loc == '/attributions' || loc == '/packs') return null;

      if (isLoading) return loc == '/loading' ? null : '/loading';

      if (loc == '/loading') {
        if (!hasQuestions) return '/packs';
        final lang = ref.read(activePackProvider.notifier).activeLang;
        final hasChar = lang != null && ref.read(characterProvider(lang)) != null;
        return hasChar ? '/game' : '/hatch';
      }

      if (!hasQuestions && (loc == '/game' || loc == '/hatch')) return '/packs';

      if (loc == '/game') {
        final lang = ref.read(activePackProvider.notifier).activeLang;
        final hasChar = lang != null && ref.read(characterProvider(lang)) != null;
        if (!hasChar) return '/hatch';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
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
      GoRoute(
        path: '/attributions',
        builder: (context, state) => const AttributionsScreen(),
      ),
    ],
  );
});

class _RefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Reports the topmost route name on push/pop/replace. Used to drive BGM
/// mode (main theme vs hourly) regardless of whether navigation came from
/// `context.go(...)` (URL-changing) or `context.push(...)` (imperative).
///
/// Filters out non-page routes (dialogs, snackbars, time pickers, dropdown
/// overlays) so they don't trigger spurious music switches. Anything go_router
/// builds is a `PageRoute` with `settings.name` set to the route's path.
class _BgmRouteObserver extends NavigatorObserver {
  final void Function(String topName) onChange;
  _BgmRouteObserver(this.onChange);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _maybeNotify(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _maybeNotify(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _maybeNotify(newRoute);

  void _maybeNotify(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || !name.startsWith('/')) return;
    onChange(name);
  }
}
