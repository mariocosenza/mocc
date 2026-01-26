import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        child: Column(
          children: [Expanded(child: SocialPostListView(key: UniqueKey()))],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: Tooltip(
          message: tr('create_post'),
          preferBelow: false,
          child: FloatingActionButton(
            onPressed: () async {
              await context.push('/app/social/create');

              setState(() {});
            },
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
