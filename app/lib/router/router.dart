import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/views/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/views/onboard_screen.dart';
import 'package:mocc/views/settings_screen.dart';
import 'package:mocc/widgets/main_shell_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      // const runningOnAzure = bool.fromEnvironment('RUNNING_ON_AZURE', defaultValue: false);
      final p = state.uri.path;

      if (!auth.ready) return null;

      if (p == '/') {
        return auth.isAuthenticated ? '/app/home' : '/onboard';
      }

      if (auth.isAuthenticated && (p == '/onboard' || p == '/login')) {
        return '/app/home';
      }

      if (p.startsWith('/app') && !auth.isAuthenticated) {
        return '/onboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SizedBox.shrink(),
      ),
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/social',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/fridge',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/shopping',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/onboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(loginPage: false),
      ),

      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(loginPage: true),
      ),

      GoRoute(
        path: '/app/settings',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final fadeIn = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );

                  final fadeOut = CurvedAnimation(
                    parent: secondaryAnimation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );

                  final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );

                  return FadeTransition(
                    opacity: fadeIn,
                    child: ScaleTransition(
                      scale: scale,
                      child: FadeTransition(
                        opacity: Tween<double>(
                          begin: 1.0,
                          end: 0.0,
                        ).animate(fadeOut),
                        child: child,
                      ),
                    ),
                  );
                },
          );
        },
      ),
    ],
  );
});
