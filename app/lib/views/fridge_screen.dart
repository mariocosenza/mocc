import 'package:flutter/material.dart';
import 'package:mocc/widgets/fridge_item_list_view.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  MenuAnchor(
                    builder: (context, controller, child) {
                      return FilledButton.tonal(
                        onPressed: () {
                          controller.isOpen
                              ? controller.close()
                              : controller.open();
                        },
                        child: const Text('Apri Opzioni'),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => print('Profilo cliccato'),
                        child: const Text('Profilo'),
                      ),
                      MenuItemButton(
                        onPressed: () => print('Impostazioni cliccate'),
                        child: const Text('Impostazioni'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // This gives the list a bounded height.
            const Expanded(child: FridgeListView()),
          ],
        ),
      )
    );
  }
}
