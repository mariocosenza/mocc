import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/views/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/widgets/main_shell_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey, 
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorKey,
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (context, state) => const HomeScreen())],
          ),
        ],
      ),

      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey, 
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

