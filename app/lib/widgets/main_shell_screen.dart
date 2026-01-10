import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/widgets/mocc_navigation_bar.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MoccNavigationBar(navigationShell: navigationShell),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


