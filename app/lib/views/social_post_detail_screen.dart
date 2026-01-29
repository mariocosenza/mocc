import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/widgets/post_more_menu.dart';
import 'package:go_router/go_router.dart';

class SocialPostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final Post? initialPost;

  const SocialPostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  ConsumerState<SocialPostDetailScreen> createState() =>
      _SocialPostDetailScreenState();
}

class _SocialPostDetailScreenState
    extends ConsumerState<SocialPostDetailScreen> {
  Post? _post;
  String? _currentUserId;
  final _commentController = TextEditingController();
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
    }
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final client = ref.read(graphQLClientProvider);
    final userSvc = UserService(client);
    final uid = await userSvc.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = uid;
      });
    }
  }

  Future<void> _addComment() async {
    if (_post == null || _commentController.text.isEmpty) return;

    setState(() => _submittingComment = true);

    try {
      final client = ref.read(graphQLClientProvider);
      final socialSvc = SocialService(client);
      final newComment = await socialSvc.addComment(
        _post!.id,
        _commentController.text,
      );

      if (mounted) {
        setState(() {
          _post!.comments.add(newComment);
          _commentController.clear();
          _submittingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingComment = false);
        debugPrint('Error adding comment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tr('post_not_found'))),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('post_details')),
        actions: [
          PostMoreMenu(
            post: _post!,
            currentUserId: _currentUserId,
            onPostUpdated: (updated) {
              setState(() {
                _post = updated;
              });
            },
            onPostDeleted: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/app/social');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Post Content
                if (_post!.imageUrl != null && _post!.imageUrl!.isNotEmpty)
                  Image.network(
                    _post!.imageUrl!,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post!.recipeSnapshot.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(_post!.caption ?? ""),
                      const SizedBox(height: 16),
                      const Divider(),
                      Text(tr('comments'), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_post!.comments.isEmpty)
                        Text(
                          tr('no_comments_yet'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),

                      ..._post!.comments.map(
                        (c) => ListTile(
                          leading: CircleAvatar(
                            child: Text(c.userNickname[0].toUpperCase()),
                          ),
                          title: Text(c.userNickname),
                          subtitle: Text(c.text),
                          trailing: Text(
                            DateFormat.MMMd().format(c.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comment Input
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                110,
              ), // Increased bottom padding to 110
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: tr('write_comment'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(100),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _submittingComment ? null : _addComment,
                    icon: _submittingComment
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
