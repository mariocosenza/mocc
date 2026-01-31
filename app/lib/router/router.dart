import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/views/fridge_screen.dart';
import 'package:mocc/views/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/views/inventory_item_edit_screen.dart';
import 'package:mocc/views/leaderboard_screen.dart';
import 'package:mocc/views/onboard_screen.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/views/recipe_screen.dart';
import 'package:mocc/views/settings_screen.dart';
import 'package:mocc/views/shopping_screen.dart';
import 'package:mocc/views/social_screen.dart';
import 'package:mocc/views/create_post_screen.dart';
import 'package:mocc/views/social_post_detail_screen.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/widgets/main_shell_screen.dart';
import 'package:mocc/views/shopping_history/add_shopping_trip_view.dart';

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

      // If unauthenticated and trying to access app, go to onboard
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
                builder: (context, state) => const SocialScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreatePostScreen(),
                  ),
                  GoRoute(
                    path: 'post/:id',
                    builder: (context, state) {
                      final post = state.extra as Post?;
                      final postId = state.pathParameters['id']!;
                      // We could pass postId to screen if post is null to fetch it (future work)
                      if (post == null) {
                        // Fallback or error, for now let's just create screen with restriction
                        return SocialPostDetailScreen(postId: postId);
                      }

                      return SocialPostDetailScreen(
                        postId: postId,
                        initialPost: post,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/fridge',
                builder: (context, state) => const FridgeScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/shopping',
                builder: (context, state) => const ShoppingScreen(),
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
        path: '/app/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/app/inventory/item',
        builder: (context, state) {
          final itemId = state.uri.queryParameters['id'];
          final fridgeId = state.uri.queryParameters['fridgeId'];

          if (itemId == null || fridgeId == null) {
            return Scaffold(
              body: Center(child: Text('missing_parameters'.tr())),
            );
          }

          return InventoryItemEditScreen(itemId: itemId, fridgeId: fridgeId);
        },
      ),

      GoRoute(
        path: '/app/recipe',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final fridge = state.extra as Fridge?;
          final recipeId = state.uri.queryParameters['id'];

          if (fridge == null) {
            return MaterialPage(
              child: Scaffold(
                body: Center(child: Text('fridge_context_required'.tr())),
              ),
            );
          }

          return CustomTransitionPage(
            key: state.pageKey,
            child: RecipeScreen(fridge: fridge, recipeId: recipeId),
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final slideIn =
                      Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );

                  final fadeIn = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  );

                  return SlideTransition(
                    position: slideIn,
                    child: FadeTransition(opacity: fadeIn, child: child),
                  );
                },
          );
        },
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
      GoRoute(
        path: '/app/shopping/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final entry = state.extra as Map<String, dynamic>?;
          return AddShoppingTripView(entry: entry);
        },
      ),
    ],
  );
});
