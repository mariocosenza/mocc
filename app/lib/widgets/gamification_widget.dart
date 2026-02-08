import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mocc/models/user_model.dart';

class GamificationProfileCard extends StatelessWidget {
  final GamificationProfile profile;
  final VoidCallback? onTap;
  final String? title;

  const GamificationProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.title,
  });

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final int threshold = profile.nextLevelThreshold <= 0
      ? 100
      : profile.nextLevelThreshold;
    final int points = profile.totalEcoPoints < 0 ? 0 : profile.totalEcoPoints;
    final double progress = (points / threshold).clamp(0.0, 1.0);

    final Color surface = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.05),
      cs.surfaceContainerHighest,
    );
    final Color onSurface = cs.onSurface;
    final Color onSurfaceVariant = cs.onSurfaceVariant;

    // True Material surface behavior.
    final double elevation = 2.0;
    final Color surfaceTint = cs.primary;

    // Inner layers (solid).
    final Color layerBg = cs.surfaceContainerHigh;
    final Color outline = _a(cs.outlineVariant, 0.45);
    final Color layerStroke = _a(cs.outlineVariant, 0.55);

    return Semantics(
      label: tr("gamification_profile"),
      child: Material(
        color: surface,
        surfaceTintColor: surfaceTint,
        elevation: elevation,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: outline),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    _IconBadge(
                      icon: Icons.eco_rounded,
                      background: layerBg,
                      foreground: onSurface,
                      border: _a(cs.outlineVariant, 0.45),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? tr("eco_progress"),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level: ${profile.currentLevel}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: onSurfaceVariant,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: tr("eco_points"),
                        value: points.toString(),
                        icon: Icons.stars_rounded,
                        color: onSurface,
                        subtle: onSurfaceVariant,
                        tint: layerBg,
                        iconTint: cs.primaryContainer,
                        border: layerStroke,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Progress to next level
                Container(
                  decoration: BoxDecoration(
                    color: layerBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: layerStroke),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tr("next_level_at_pts")} $threshold',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: _a(onSurface, 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Badges
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildBadges(
                      badges: profile.badges,
                      background: layerBg,
                      foreground: onSurface,
                      border: layerStroke,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBadges({
    required List<String> badges,
    required Color background,
    required Color foreground,
    required Color border,
  }) {
    if (badges.isEmpty) {
      return [
        _BadgeChip(
          text: tr("no_badges_yet"),
          icon: Icons.emoji_events_outlined,
          background: background,
          foreground: _a(foreground, 0.85),
          border: border,
        ),
      ];
    }

    const int cap = 6;
    final shown = badges.take(cap).toList();
    final remaining = badges.length - shown.length;

    final chips = shown
        .map(
          (b) => _BadgeChip(
            text: b,
            icon: Icons.verified_rounded,
            background: background,
            foreground: _a(foreground, 0.92),
            border: border,
          ),
        )
        .toList();

    if (remaining > 0) {
      chips.add(
        _BadgeChip(
          text: '+$remaining',
          icon: Icons.add_rounded,
          background: background,
          foreground: _a(foreground, 0.95),
          border: border,
        ),
      );
    }

    return chips;
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  const _IconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: foreground),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color subtle;
  final Color tint;
  final Color iconTint;
  final Color border;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtle,
    required this.tint,
    required this.iconTint,
    required this.border,
  });

  static Color _a(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _a(cs.outlineVariant, 0.45)),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  const _BadgeChip({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
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
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
