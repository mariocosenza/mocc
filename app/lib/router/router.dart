import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/views/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/widgets/main_shell_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/app/home',
    refreshListenable: auth,
    redirect: (context, state) {
      const runningOnAzure = bool.fromEnvironment('RUNNING_ON_AZURE', defaultValue: false);
      if (!runningOnAzure) return null;

      if (!auth.ready) return null;

      final p = state.uri.path;
      final inApp = p.startsWith('/app');

      if (inApp && !auth.isAuthenticated) {
        return '/onboard';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorKey,
            routes: [
              GoRoute(
                path: '/app/home',
                builder: (context, state) => const HomeScreen(),
              )
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/settings',
                builder: (context, state) => const HomeScreen(),
              )
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/onboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

