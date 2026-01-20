import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/social_service.dart';

class PostMoreMenu extends ConsumerWidget {
  final Post post;
  final String? currentUserId;
  final VoidCallback? onPostDeleted;
  final ValueChanged<Post>? onPostUpdated;

  const PostMoreMenu({
    super.key,
    required this.post,
    required this.currentUserId,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentUserId != post.authorId) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') {
          _showEditDialog(context, ref);
        } else if (value == 'delete') {
          _showDeleteDialog(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              Text(tr('edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                tr('delete'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: post.caption);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('edit_post')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('caption'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () async {
                  try {
                    final client = ref.read(graphQLClientProvider);
                    final svc = SocialService(client);
                    final updated = await svc.updatePost(
                      post.id,
                      controller.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      onPostUpdated?.call(updated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('post_updated'))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr('error_occurred', args: [e.toString()]),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(tr('save')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_post')),
        content: Text(tr('delete_post_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () async {
                  try {
                    final client = ref.read(graphQLClientProvider);
                    final svc = SocialService(client);
                    await svc.deletePost(post.id);
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      onPostDeleted?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('post_deleted'))),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr('error_occurred', args: [e.toString()]),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  tr('delete'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
