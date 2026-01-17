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
    return '$valueStr ${q.unit}';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final expired = _isExpired(item.expiryDate);
    final expirySoon = _isExpirySoon(item.expiryDate) && !expired;

    final Color warning = expired ? cs.error : cs.tertiary;

    final Color surface = cs.surface;
    final Color onSurface = cs.onSurface;
    final Color onSurfaceVariant = cs.onSurfaceVariant;

    final Color border = (expired || expirySoon)
        ? warning.withValues(alpha: 220)
        : cs.outlineVariant.withValues(alpha: 140);

    final Color chipBg = cs.surfaceContainer;
    final Color chipBorder = cs.outlineVariant.withValues(alpha: 140);

    final String expiryText = _formatDate(item.expiryDate);

    final brand = item.brand?.trim();
    final category = item.category?.trim();

    return Semantics(
      label: '${tr("fridge_item")}${item.name}',
      child: Material(
        color: surface,
        surfaceTintColor: cs.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: border,
            width: (expired || expirySoon) ? 1.2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (expired || expirySoon) ...[
                      const SizedBox(width: 8),
                      _MiniStatusPill(
                        text: expired ? tr("expired") : tr("expireing"),
                        icon: expired
                            ? Icons.error_outline_rounded
                            : Icons.warning_amber_rounded,
                        fg: warning,
                        bg: warning.withValues(alpha: 35),
                        border: warning.withValues(alpha: 80),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // Brand + Category (compact chips)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.storefront_outlined,
                      label: (brand != null && brand.isNotEmpty) ? brand : '—',
                      bg: chipBg,
                      fg: onSurfaceVariant,
                      border: chipBorder,
                      tooltip: tr("brand"),
                    ),
                    _MiniChip(
                      icon: Icons.category_outlined,
                      label: (category != null && category.isNotEmpty) ? category : '—',
                      bg: chipBg,
                      fg: onSurfaceVariant,
                      border: chipBorder,
                      tooltip: tr("category"),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Compact 2-column facts
                Row(
                  children: [
                    Expanded(
                      child: _CompactKV(
                        icon: Icons.scale_outlined,
                        label: tr("quantity"),
                        value: _formatQuantity(item.quantity),
                        labelColor: onSurfaceVariant,
                        valueColor: onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactKV(
                        icon: Icons.euro_rounded,
                        label: tr("price"),
                        value: _formatPrice(item.price),
                        labelColor: onSurfaceVariant,
                        valueColor: onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child: _CompactKV(
                        icon: Icons.event_outlined,
                        label: tr("expire"),
                        value: expiryText,
                        labelColor: onSurfaceVariant,
                        valueColor: (expired || expirySoon) ? warning : onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactKV(
                        icon: Icons.lock_outline,
                        label: tr("in_use"),
                        value: (item.activeLocks?.length ?? 0).toString(),
                        labelColor: onSurfaceVariant,
                        valueColor: onSurface,
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
                        border: chipBorder,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FooterTag(
                        icon: Icons.cloud_outlined,
                        text: item.virtualAvailable.toString(),
                        bg: cs.surfaceContainerHighest,
                        fg: onSurfaceVariant,
                        border: chipBorder,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FooterTag(
                        icon: Icons.timelapse_outlined,
                        text: _enumLabel(item.expiryType),
                        bg: cs.surfaceContainerHighest,
                        fg: onSurfaceVariant,
                        border: chipBorder,
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

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({
    required this.text,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String text;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactKV extends StatelessWidget {
  const _CompactKV({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
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
  const _FooterTag({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  final Color border;

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
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
