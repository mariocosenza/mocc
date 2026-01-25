import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:go_router/go_router.dart';

import 'package:mocc/widgets/post_more_menu.dart';

class SocialPostListiView extends ConsumerStatefulWidget {
  const SocialPostListiView({super.key});

  @override
  ConsumerState<SocialPostListiView> createState() =>
      _SocialPostListiViewState();
}

class _SocialPostListiViewState extends ConsumerState<SocialPostListiView>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Post> _allPosts = [];
  String? _currentUserId;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final client = ref.read(graphQLClientProvider);
      final socialSvc = SocialService(client);
      final userSvc = UserService(client);

      final results = await Future.wait([
        socialSvc.getFeed(
          limit: 50,
        ), // Fetch more to support client-side filtering better
        userSvc.getUserId(),
      ]);

      if (mounted) {
        setState(() {
          _allPosts = results[0] as List<Post>;
          _currentUserId = results[1] as String;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Log error to console but don't expose to UI
        debugPrint('Social load error: $e');
        setState(() {
          _error = 'error_loading_feed'; // Use a key or generic message
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    if (_currentUserId == null) return;
    final isLiked = post.isLikedBy(_currentUserId!);
    final client = ref.read(graphQLClientProvider);
    final socialSvc = SocialService(client);

    try {
      Post updatedPost;
      if (isLiked) {
        updatedPost = await socialSvc.unlikePost(post.id);
      } else {
        updatedPost = await socialSvc.likePost(post.id);
      }

      if (mounted) {
        setState(() {
          final index = _allPosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            _allPosts[index] = updatedPost;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error toggling like: $e');
      }
    }
  }

  void _onPostUpdated(Post updatedPost) {
    setState(() {
      final index = _allPosts.indexWhere((p) => p.id == updatedPost.id);
      if (index != -1) {
        _allPosts[index] = updatedPost;
      }
    });
  }

  void _onPostDeleted(String postId) {
    setState(() {
      _allPosts.removeWhere((p) => p.id == postId);
    });
  }

  Widget _buildPostList(List<Post> posts) {
    if (posts.isEmpty) {
      return Center(child: Text(tr('no_entries_yet')));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: posts.length,
        separatorBuilder: (c, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = posts[index];
          return _PostCard(
            post: post,
            currentUserId: _currentUserId,
            onLike: () => _toggleLike(post),
            onTap: () {
              context.push('/app/social/post/${post.id}', extra: post);
            },
            onPostUpdated: _onPostUpdated,
            onPostDeleted: () => _onPostDeleted(post.id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialRefreshProvider, (previous, next) {
      _loadData();
    });

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('something_went_wrong')),
            // Text(_error!), // Don't show raw error
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadData, child: Text(tr('retry'))),
          ],
        ),
      );
    }

    final myPosts = _allPosts
        .where((p) => p.authorId == _currentUserId)
        .toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('feed')),
            Tab(text: tr('my_posts')),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildPostList(_allPosts), _buildPostList(myPosts)],
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onTap;
  final ValueChanged<Post> onPostUpdated;
  final VoidCallback onPostDeleted;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onTap,
    required this.onPostUpdated,
    required this.onPostDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLiked = currentUserId != null && post.isLikedBy(currentUserId!);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      post.authorNickname.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorNickname,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat.yMMMd().format(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PostMoreMenu(
                    post: post,
                    currentUserId: currentUserId,
                    onPostUpdated: onPostUpdated,
                    onPostDeleted: onPostDeleted,
                  ),
                ],
              ),
            ),
            // Image (Placeholder or Real)
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Image.network(
                post.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 200,
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              Container(
                height: 150,
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant, size: 48, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(
                      post.recipeSnapshot.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    Text(post.caption!),
                    const SizedBox(height: 8),
                  ],
                  // Recipe Card / Snippet
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withAlpha(80),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 16, color: cs.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.recipeSnapshot.title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? cs.tertiary : null,
                    ),
                    onPressed: onLike,
                  ),
                  Text('${post.likesCount}'),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: onTap, // Go to details to comment
                  ),
                  Text('${post.comments.length}'),
                  const Spacer(),
                  // Eco points badge if applicable
                  if ((post.recipeSnapshot.ecoPointsReward ?? 0) > 0)
                    Chip(
                      label: Text(
                        '+${post.recipeSnapshot.ecoPointsReward} ${tr('eco_pts_suffix')}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.primary.withAlpha(50),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
