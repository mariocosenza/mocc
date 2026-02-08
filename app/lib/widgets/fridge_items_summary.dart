import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mocc/models/inventory_model.dart';

class _FoodItemStats {
  final int totalItems;
  final int expiringSoon;
  final int expiredItems;

  const _FoodItemStats({
    required this.totalItems,
    required this.expiringSoon,
    required this.expiredItems,
  });
}

class FridgeItemsSummary extends StatelessWidget {
  final Fridge fridge;
  final Duration expirySoonThreshold;
  final VoidCallback? onTap;
  final String title;

  const FridgeItemsSummary({
    super.key,
    required this.fridge,
    this.expirySoonThreshold = const Duration(days: 3),
    this.onTap,
    this.title = 'Fridge Summary',
  });

  _FoodItemStats _foodStats(Fridge fridge) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final soonThreshold = today.add(expirySoonThreshold);

    int total = fridge.items.length;
    int expSoon = 0;
    int expired = 0;

    for (final item in fridge.items) {
      final exp = item.expiryDate;
      final expDay = DateTime(exp.year, exp.month, exp.day);

      if (expDay.isBefore(today)) {
        expired += 1;
      } else if (expDay.isBefore(soonThreshold) ||
          expDay.isAtSameMomentAs(soonThreshold)) {
        expSoon += 1;
      }
    }

    return _FoodItemStats(
      totalItems: total,
      expiringSoon: expSoon,
      expiredItems: expired,
    );
  }

  static Color _alpha(Color c, int a) => c.withAlpha(a);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final stats = _foodStats(fridge);

    final surface = cs.surfaceContainer;
    final cardBorder = _alpha(cs.outlineVariant, 160);

    final subSurface = cs.surfaceContainer;
    final subBorder = _alpha(cs.outlineVariant, 130);

    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    final ok = cs.primary;
    final warning = cs.tertiary;
    final danger = cs.error;

    final int atRisk = stats.expiringSoon + stats.expiredItems;
    final double health = stats.totalItems == 0
        ? 1.0
        : (1.0 - (atRisk / stats.totalItems)).clamp(0.0, 1.0);

    final Color accent = stats.expiredItems > 0
        ? danger
        : (stats.expiringSoon > 0 ? warning : ok);

    final String statusText = stats.totalItems == 0
        ? 'empty'.tr()
        : (stats.expiredItems > 0
              ? 'needs_attention'.tr()
              : (stats.expiringSoon > 0 ? 'watchlist'.tr() : 'all_good'.tr()));

    return Semantics(
      label: 'fridge_items_summary'.tr(),
      child: Material(
        color: surface,
        surfaceTintColor: cs.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _IconBadge(
                      icon: Icons.kitchen_rounded,
                      bg: cs.surfaceContainerHighest,
                      fg: onSurface,
                      border: cardBorder,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fridge.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(
                      text: statusText,
                      fg: onSurfaceVariant,
                      bg: cs.surfaceContainerHighest,
                      border: cardBorder,
                      dot: accent,
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: onSurfaceVariant,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'total'.tr(),
                        value: stats.totalItems.toString(),
                        icon: Icons.inventory_2_outlined,
                        iconColor: ok,
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                        bg: subSurface,
                        border: subBorder,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: 'expiring'.tr(),
                        value: stats.expiringSoon.toString(),
                        icon: Icons.warning_amber_rounded,
                        iconColor: warning,
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                        bg: subSurface,
                        border: subBorder,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: 'expired'.tr(),
                        value: stats.expiredItems.toString(),
                        icon: Icons.error_outline_rounded,
                        iconColor: danger,
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                        bg: subSurface,
                        border: subBorder,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Health bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: subSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: subBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stats.totalItems == 0
                                  ? 'add_items_to_start_tracking'.tr()
                                  : 'freshness_health'.tr(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(health * 100).round()}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: onSurface,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: health,
                          minHeight: 8,
                          backgroundColor: _alpha(onSurface, 18),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;

  const _IconBadge({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final Color border;
  final Color dot;

  const _StatusChip({
    required this.text,
    required this.fg,
    required this.bg,
    required this.border,
    required this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color fg;
  final Color subtle;
  final Color bg;
  final Color border;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.fg,
    required this.subtle,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: subtle,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
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
