import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoccNavigationBar extends StatelessWidget {
  const MoccNavigationBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final double pillWidth = MediaQuery.sizeOf(context).width * 0.86;

    return SizedBox(
      width: pillWidth,
      height: 65,      
      child: Material(
        elevation: 12,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias, 
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.all(const IconThemeData(size: 25)),
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
