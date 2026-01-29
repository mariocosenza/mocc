import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/social_service.dart';

import '../service/graphql_config.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late final userService = ref.read(graphQLClientProvider);
  late final SocialService socialService = SocialService(userService);
  late final Future<List<LeaderboardEntry>> entries = socialService
      .getLeaderboard(top: 50);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: entries,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (asyncSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('leaderboard').tr()),
            body: Center(
              child: Text(
                tr('error_occurred', args: [asyncSnapshot.error.toString()]),
              ),
            ),
          );
        }
        final entriesList = asyncSnapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('leaderboard').tr()),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: entriesList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = entriesList[index];
              return _LeaderboardListTile(
                rank: e.rank,
                nickname: e.nickname,
                score: e.score,
              );
            },
          ),
        );
      },
    );
  }
}

class _LeaderboardListTile extends StatelessWidget {
  final int rank;
  final String nickname;
  final int score;

  const _LeaderboardListTile({
    required this.rank,
    required this.nickname,
    required this.score,
  });

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = _a(cs.surface, 1.0);
    final border = _a(cs.onSurface, 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 8),
            color: _a(Theme.of(context).colorScheme.shadow, 0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 38,
            decoration: BoxDecoration(
              color: _a(cs.primaryContainer, 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nickname,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            score.toString(),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
