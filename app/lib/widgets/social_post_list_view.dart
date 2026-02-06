import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/server_health_service.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/service/signal_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:go_router/go_router.dart';

import 'package:mocc/widgets/post_more_menu.dart';
import 'package:mocc/widgets/unified_error_widget.dart';

class SocialPostListView extends ConsumerStatefulWidget {
  const SocialPostListView({super.key});

  @override
  ConsumerState<SocialPostListView> createState() => _SocialPostListViewState();
}

class _SocialPostListViewState extends ConsumerState<SocialPostListView>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isFetching = false;
  Object? _error;
  List<Post> _allPosts = [];
  String? _currentUserId;
  late final TabController _tabController;
  DateTime? _lastSuccessfulLoadAt;
  bool _refreshQueued = false;

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
    if (_isFetching) return;
    _isFetching = true;
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final client = ref.read(graphQLClientProvider);
      final socialSvc = SocialService(client);
      final userSvc = UserService(client);

      final results = await Future.wait([
        socialSvc.getFeed(limit: 50),
        userSvc.getUserId(),
      ]);

      if (mounted) {
        setState(() {
          _allPosts = results[0] as List<Post>;
          _currentUserId = results[1] as String;
          _loading = false;
        });
        _lastSuccessfulLoadAt = DateTime.now();
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Social load error: $e');
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    } finally {
      _isFetching = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        _loadData();
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
    final serverStatus = ref.watch(serverHealthProvider);
    ref.listen<ServerStatus>(serverHealthProvider, (previous, next) {
      if (next == ServerStatus.online && previous != ServerStatus.online) {
        if (_isFetching) {
          _refreshQueued = true;
          return;
        }
        if (_lastSuccessfulLoadAt != null) {
          final sinceLastSuccess =
              DateTime.now().difference(_lastSuccessfulLoadAt!);
          if (sinceLastSuccess < const Duration(seconds: 5)) {
            return;
          }
        }
        debugPrint('[Social] Server is now online, auto-refreshing...');
        _loadData();
      }
    });

    ref.listen(signalRefreshProvider, (_, _) {
      debugPrint('[Social] SignalR refresh received');
      if (!_isFetching) {
        _loadData();
      }
    });

    ref.listen(socialRefreshProvider, (previous, next) {
      if (!_isFetching) {
        _loadData();
      }
    });

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && serverStatus == ServerStatus.online) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: UnifiedErrorWidget(error: _error, onRetry: _loadData),
                ),
              ),
            ),
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
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Stack(
                children: [
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
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: cs.primaryContainer.withAlpha(200),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: theme.scaffoldBackgroundColor,
                                appBar: AppBar(
                                  backgroundColor:
                                      theme.scaffoldBackgroundColor,
                                  iconTheme: IconThemeData(color: cs.onSurface),
                                ),
                                body: Center(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      post.imageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 64,
                                                  color:
                                                      theme.colorScheme.error,
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
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    Text(post.caption!),
                    const SizedBox(height: 8),
                  ],
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
                    onPressed: onTap,
                  ),
                  Text('${post.comments.length}'),
                  const Spacer(),
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
