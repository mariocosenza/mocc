import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/models/models.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/widgets/ai_recipe_home.dart';
import 'package:mocc/widgets/equal_height_row.dart';
import 'package:mocc/widgets/gamification_widget.dart';
import 'package:mocc/widgets/home_leader_card.dart';
import 'package:mocc/widgets/microsoft_profile_avatar.dart';

class _HomeData {
  final GamificationProfile gamification;
  final List<LeaderboardEntry> leaderboardTop5;
  final List<Recipe> recommendedRecipes;

  const _HomeData({
    required this.gamification,
    required this.leaderboardTop5,
    required this.recommendedRecipes,
  });
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<_HomeData> _loadData(WidgetRef ref) async {
    final client = ref.read(graphQLClientProvider);

    final userSvc = UserService(client);
    final socialSvc = SocialService(client);
    final recipeSvc = RecipeService(client);

    final results = await Future.wait([
      userSvc.getMe(),
      socialSvc.getLeaderboard(top: 5),
      recipeSvc.getMyAiRecipes(status: RecipeStatus.proposed),
    ]);

    final me = results[0] as User;
    final leaderboard = results[1] as List<LeaderboardEntry>;
    final recipes = results[2] as List<Recipe>;

    return _HomeData(
      gamification: me.gamification,
      leaderboardTop5: leaderboard,
      recommendedRecipes: recipes,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: auth,
          builder: (context, _) {
            return FutureBuilder<_HomeData>(
              future: _loadData(ref),
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                final hasError = snapshot.hasError;
                final data = snapshot.data;

                return RefreshIndicator(
                  onRefresh: () async {
                    (context as Element).markNeedsBuild();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 150),
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              MicrosoftProfileAvatar(
                                isAuthenticated: auth.isAuthenticated,
                                getGraphToken: () => auth.acquireAccessToken(
                                  scopes: const ['User.Read'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (hasError)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: _ErrorCard(
                              error: snapshot.error,
                              onRetry: () =>
                                  (context as Element).markNeedsBuild(),
                            ),
                          ),
                        ),

                      if (loading && !hasError)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: _HomeLoading()),
                        ),

                      if (!loading && !hasError && data != null)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              LayoutBuilder(
                                builder: (context, c) {
                                  final isWide = c.maxWidth >= 720;

                                  final gamification = GamificationProfileCard(
                                    profile: data.gamification,
                                  );

                                  final leaderboard = HomeLeaderboardCard(
                                    top5: data.leaderboardTop5,
                                  );

                                  if (isWide) {
                                    return EqualHeightRow(
                                      left: gamification,
                                      right: leaderboard,
                                      gap: 12,
                                    );
                                  }

                                  return Column(
                                    children: [
                                      gamification,
                                      const SizedBox(height: 12),
                                      leaderboard,
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              _RecipeSection(recipes: data.recommendedRecipes),

                              const SizedBox(height: 24),
                            ]),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  final List<Recipe> recipes;

  const _RecipeSection({required this.recipes});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return _EmptyStateCard(
        title: tr("no_recommended_recipes"),
        message: tr("no_recommended_recipes_message"),
        icon: Icons.auto_awesome_rounded,
      );
    }

    return AiRecipeOfTheDayCard(recipe: recipes.first, showTitle: false);
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget block({double h = 16, double r = 16}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Column(
      children: [
        block(h: 230, r: 20),
        const SizedBox(height: 12),
        block(h: 230, r: 22),
        const SizedBox(height: 16),
        block(h: 160, r: 20),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.errorContainer,
      surfaceTintColor: cs.error,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr("something_went_wrong"),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error?.toString() ?? tr("unknown_error"),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _withAlpha(cs.onErrorContainer, 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: onRetry, child: const Text('retry').tr()),
          ],
        ),
      ),
    );
  }

  static Color _withAlpha(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      surfaceTintColor: cs.primary,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
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
