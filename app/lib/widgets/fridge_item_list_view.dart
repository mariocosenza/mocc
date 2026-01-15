import 'package:flutter/material.dart';

class FridgeListView extends StatelessWidget {
  const FridgeListView({super.key});

  static final entries = <String>['A', 'B', 'C'];
  static final colorCodes = <int>[600, 500, 100];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Header'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) => Container(
              height: 50,
              color: Colors.amber[colorCodes[index]],
              alignment: Alignment.center,
              child: Text('Entry ${entries[index]}'),
            ),
          ),
        ),
      ],
    );
  }
}
