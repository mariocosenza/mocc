import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/models/models.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/inventory_service.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/widgets/ai_recipe_home.dart';
import 'package:mocc/widgets/equal_height_row.dart';
import 'package:mocc/widgets/fridge_items_summary.dart';
import 'package:mocc/widgets/gamification_widget.dart';
import 'package:mocc/widgets/home_leader_card.dart';
import 'package:mocc/widgets/microsoft_profile_avatar.dart';
import 'package:mocc/service/error_helper.dart';

class _HomeData {
  final GamificationProfile gamification;
  final List<LeaderboardEntry> leaderboardTop5;
  final List<Recipe> recommendedRecipes;

  /// Only one fridge: first fridge whose id == userId (if found), else null.
  final Fridge? fridge;

  const _HomeData({
    required this.gamification,
    required this.leaderboardTop5,
    required this.recommendedRecipes,
    required this.fridge,
  });
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData(ref);
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData(ref);
    });
    try {
      await _dataFuture;
    } catch (_) {
      // Error is handled by FutureBuilder
    }
  }

  Future<_HomeData> _loadData(WidgetRef ref) async {
    final client = ref.read(graphQLClientProvider);

    final userSvc = UserService(client);
    final socialSvc = SocialService(client);
    final recipeSvc = RecipeService(client);
    final inventorySvc = InventoryService(client);

    final results = await Future.wait([
      userSvc.getMe(),
      socialSvc.getLeaderboard(top: 5),
      recipeSvc.getMyAiRecipes(status: RecipeStatus.proposed),
      inventorySvc.getMyFridges(),
    ]);

    final me = results[0] as User;
    final leaderboard = results[1] as List<LeaderboardEntry>;
    final recipes = results[2] as List<Recipe>;
    final fridges = results[3] as List<Fridge>;

    final userId = me.id;
    Fridge? selected;
    for (final f in fridges) {
      if (f.id == userId) {
        selected = f;
        break;
      }
    }

    return _HomeData(
      gamification: me.gamification,
      leaderboardTop5: leaderboard,
      recommendedRecipes: recipes,
      fridge: selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: auth,
          builder: (context, _) {
            return FutureBuilder<_HomeData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                final hasError = snapshot.hasError;
                final data = snapshot.data;

                return RefreshIndicator(
                  onRefresh: _refresh,
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
                                onConsentNeeded: () =>
                                    auth.consent(scopes: const ['User.Read']),
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
                              onRetry: _refresh,
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
                              // ✅ MOVE SUMMARY TO THE TOP (no elevation handled inside widget)
                              if (data.fridge != null) ...[
                                FridgeItemsSummary(
                                  fridge: data.fridge!,
                                  title: tr('fridge_item'),
                                  // onTap: () => context.push('/app/fridge'),
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                _InlineHint(
                                  text: tr('no_fridge_found'),
                                  icon: Icons.kitchen_rounded,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Existing top row (Gamification + Leaderboard)
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 60.0),
      child: AiRecipeOfTheDayCard(recipe: recipes.first, showTitle: false),
    );
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
        // ✅ add a placeholder for the summary on top (no elevation look)
        block(h: 140, r: 16),
        const SizedBox(height: 12),

        block(h: 230, r: 20),
        const SizedBox(height: 12),
        block(h: 230, r: 22),
        const SizedBox(height: 16),
        block(h: 160, r: 20),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InlineHint({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 140)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 140),
              ),
            ),
            child: Icon(icon, color: cs.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
                    getErrorMessage(error).tr(),
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
