import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/social_model.dart';

class HomeLeaderboardCard extends StatelessWidget {
  final List<LeaderboardEntry> top5;

  const HomeLeaderboardCard({super.key, required this.top5});

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final entries = top5.take(5).toList();

    final Color surface = cs.secondaryContainer;
    final Color onSurface = cs.onSecondaryContainer;
    final Color onSurfaceVariant = cs.onSecondaryContainer;
    final double elevation = 2.0;
    final Color surfaceTint = cs.secondary;

    // Inner layers
    final Color layerBg = _a(onSurface, 0.08);
    final Color layerBorder = _a(onSurface, 0.14);
    final Color outline = _a(cs.outlineVariant, 0.45);

    return Semantics(
      label: 'Leaderboard preview',
      child: Material(
        color: surface,
        surfaceTintColor: surfaceTint,
        elevation: elevation,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/app/leaderboard'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: outline),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _Pill(
                      icon: Icons.leaderboard_rounded,
                      text: tr("leaderboard"),
                      foreground: onSurface,
                      background: _a(onSurface, 0.10),
                      border: _a(onSurface, 0.16),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _a(onSurface, 0.92),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                if (entries.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr("no_entries_yet"),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _a(onSurfaceVariant, 0.90),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final e in entries) ...[
                        _HomeLeaderboardRow(
                          rank: e.rank,
                          nickname: e.nickname,
                          score: e.score,
                          ink: onSurface,
                          tileBg: layerBg,
                          tileBorder: layerBorder,
                        ),
                        if (e != entries.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLeaderboardRow extends StatelessWidget {
  final int rank;
  final String nickname;
  final int score;
  final Color ink;
  final Color tileBg;
  final Color tileBorder;

  const _HomeLeaderboardRow({
    required this.rank,
    required this.nickname,
    required this.score,
    required this.ink,
    required this.tileBg,
    required this.tileBorder,
  });

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, ink: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _a(ink, 0.94),
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _a(ink, 0.92),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color ink;

  const _RankBadge({required this.rank, required this.ink});

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  IconData get _icon {
    if (rank == 1) return Icons.emoji_events_rounded;
    if (rank == 2) return Icons.workspace_premium_rounded;
    if (rank == 3) return Icons.military_tech_rounded;
    return Icons.tag_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 36,
      decoration: BoxDecoration(
        color: _a(ink, 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _a(ink, 0.16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 16, color: _a(ink, 0.96)),
          const SizedBox(width: 4),
          Text(
            '$rank',
            style: TextStyle(
              color: _a(ink, 0.96),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;
  final Color border;

  const _Pill({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
