import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/views/home_page.dart';

final GoRouter goRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomePage();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'onboard',
          builder: (BuildContext context, GoRouterState state) {
            return const HomePage();
          },
        ),
      ],
    ),
  ],
);