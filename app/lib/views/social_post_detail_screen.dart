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
  bool _loadingPost = false;
  Object? _postError;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
    } else {
      _loadPost();
    }
    _loadCurrentUser();
  }

  Future<void> _loadPost() async {
    setState(() {
      _loadingPost = true;
      _postError = null;
    });

    try {
      final client = ref.read(graphQLClientProvider);
      final socialSvc = SocialService(client);
      final post = await socialSvc.getPostById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loadingPost = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postError = e;
        _loadingPost = false;
      });
    }
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
    if (_loadingPost) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      final message = _postError == null
          ? tr('post_not_found')
          : tr('error_occurred', args: [_postError.toString()]);
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(message)),
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
                  Stack(
                    children: [
                      Image.network(
                        _post!.imageUrl!,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Material(
                          color: cs.primaryContainer.withAlpha(200),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    backgroundColor:
                                        theme.scaffoldBackgroundColor,
                                    appBar: AppBar(
                                      backgroundColor:
                                          theme.scaffoldBackgroundColor,
                                      iconTheme: IconThemeData(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    body: Center(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          _post!.imageUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 64,
                                                      color: theme
                                                          .colorScheme
                                                          .error,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.fullscreen,
                                color: cs.onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

                      Text(
                        tr('ingredients'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_post!.recipeSnapshot.ingredients.isEmpty)
                        Text(
                          tr('no_ingredients'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ..._post!.recipeSnapshot.ingredients.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Text(
                                  '${e.name} (${e.quantity} ${e.unit.toString().split('.').last})',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        tr('preparation'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_post!.recipeSnapshot.steps.isEmpty)
                        Text(tr('no_steps'), style: theme.textTheme.bodyMedium),
                      ..._post!.recipeSnapshot.steps.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: cs.secondaryContainer,
                                child: Text(
                                  '${e.key + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

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
                          subtitle: Text(c.removed
                              ? tr('comment_removed_moderation')
                              : c.text),
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
