import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mocc/models/inventory_model.dart';

class FridgeItem extends StatelessWidget {
  const FridgeItem({
    super.key,
    required this.item,
    this.onTap,
    this.expirySoonThreshold = const Duration(days: 3),
  });

  final InventoryItem item;
  final VoidCallback? onTap;
  final Duration expirySoonThreshold;

  bool _isExpirySoon(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diff = exp.difference(today);
    return diff.inDays <= expirySoonThreshold.inDays && diff.inDays >= 0;
  }

  bool _isExpired(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.isBefore(today);
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  String _formatQuantity(Quantity q) {
    final v = q.value;
    final valueStr = (v % 1 == 0) ? v.toInt().toString() : v.toString();
    return '$valueStr ${q.unit.toString()}';
  }

  String _formatPrice(double? price) {
    if (price == null) return '—';
    return '${price.toStringAsFixed(2)} €';
  }

  String _enumLabel(Object e) {
    final s = e.toString();
    final dot = s.indexOf('.');
    return dot >= 0 ? s.substring(dot + 1) : s;
  }

  static Color _alpha(Color c, int a) => c.withValues(alpha: a.toDouble());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final expired = _isExpired(item.expiryDate);
    final expirySoon = _isExpirySoon(item.expiryDate) && !expired;


    final Color accent =
        expired ? cs.error : (expirySoon ? cs.tertiary : cs.primary);


    final Color surface = cs.surfaceContainerLowest;
    final Color inner = cs.surfaceContainer;
    final Color border = _alpha(cs.outlineVariant, 150);

    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    final String expiryText = _formatDate(item.expiryDate);

    final brand = item.brand?.trim();
    final category = item.category?.trim();

    return Semantics(
      label: '${tr("fridge_item")} ${item.name}',
      child: Material(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with accent bar
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (expired || expirySoon)
                      _StatusChip(
                        text: expired ? tr("expired") : tr("expireing"),
                        dot: accent,
                        fg: onSurfaceVariant,
                        bg: cs.surfaceContainerHighest,
                        border: border,
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Brand / Category
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.storefront_outlined,
                      label: (brand != null && brand.isNotEmpty) ? brand : '—',
                      bg: inner,
                      fg: onSurfaceVariant,
                      border: border,
                      tooltip: tr("brand"),
                    ),
                    _MiniChip(
                      icon: Icons.category_outlined,
                      label:
                          (category != null && category.isNotEmpty) ? category : '—',
                      bg: inner,
                      fg: onSurfaceVariant,
                      border: border,
                      tooltip: tr("category"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Details
                Row(
                  children: [
                    Expanded(
                      child: _KV(
                        icon: Icons.scale_outlined,
                        label: tr("quantity"),
                        value: _formatQuantity(item.quantity),
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KV(
                        icon: Icons.euro_rounded,
                        label: tr("price"),
                        value: _formatPrice(item.price),
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child: _KV(
                        icon: Icons.event_outlined,
                        label: tr("expire"),
                        value: expiryText,
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KV(
                        icon: Icons.lock_outline,
                        label: tr("in_use"),
                        value: (item.activeLocks?.length ?? 0).toString(),
                        fg: onSurface,
                        subtle: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Footer tags
                Row(
                  children: [
                    Expanded(
                      child: _FooterTag(
                        icon: Icons.info_outline,
                        text: _enumLabel(item.status),
                        bg: cs.surfaceContainerHighest,
                        fg: onSurfaceVariant,
                        border: border,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FooterTag(
                        icon: Icons.cloud_outlined,
                        text: item.virtualAvailable.toString(),
                        bg: cs.surfaceContainerHighest,
                        fg: onSurfaceVariant,
                        border: border,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FooterTag(
                        icon: Icons.timelapse_outlined,
                        text: _enumLabel(item.expiryType),
                        bg: cs.surfaceContainerHighest,
                        fg: onSurfaceVariant,
                        border: border,
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final String tooltip;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color fg;
  final Color subtle;

  const _KV({
    required this.icon,
    required this.label,
    required this.value,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: subtle),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: subtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  const _FooterTag({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
