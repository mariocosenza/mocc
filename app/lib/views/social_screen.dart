import 'package:flutter/material.dart';
import 'package:mocc/widgets/social_post_list_view.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: const [Expanded(child: SocialPostListiView())]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: Tooltip(
          message: 'Increment',
          preferBelow: false,
          child: FloatingActionButton(
            onPressed: () {},
            heroTag: 'social_fab',
            elevation: 24,
            highlightElevation: 28,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.post_add, size: 28),
          ),
        ),
      ),
    );
  }
}
