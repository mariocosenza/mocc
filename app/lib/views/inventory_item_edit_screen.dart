import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mocc/models/enums.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/inventory_service.dart';

class InventoryItemEditScreen extends ConsumerStatefulWidget {
  final String fridgeId;
  final String itemId;

  const InventoryItemEditScreen({
    super.key,
    required this.fridgeId,
    required this.itemId,
  });

  @override
  ConsumerState<InventoryItemEditScreen> createState() =>
      _InventoryItemEditScreenState();
}

class _InventoryItemEditScreenState
    extends ConsumerState<InventoryItemEditScreen> {
  late final InventoryService inventorySvc;

  Future<InventoryItem>? _future;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  DateTime? _expiryDate;
  Unit? _unit; // locked
  double _virtualAvailable = 0;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(graphQLClientProvider);
    inventorySvc = InventoryService(client);
    _future = _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _categoryCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _enumLabel(Object? e) {
    if (e == null) return '—';
    final s = e.toString();
    final dot = s.indexOf('.');
    return dot >= 0 ? s.substring(dot + 1) : s;
  }

  Future<InventoryItem> _load() async {
    final item = await inventorySvc.getInventoryItem(widget.itemId);

    _nameCtrl.text = item.name;
    _brandCtrl.text = item.brand ?? '';
    _categoryCtrl.text = item.category ?? '';
    _quantityCtrl.text = _fmtNum(item.quantity.value);
    _priceCtrl.text = item.price == null ? '' : _fmtNum(item.price!);
    _expiryDate = item.expiryDate;
    _unit = item.quantity.unit;
    _virtualAvailable = item.virtualAvailable;

    return item;
  }

  static String _fmtNum(num v) {
    final s = v.toString();
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  double? _parseDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiryDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );

    if (picked == null) return;
    setState(
      () => _expiryDate = DateTime(picked.year, picked.month, picked.day),
    );
  }

  bool get _quantityBelowVirtual {
    final q = _parseDouble(_quantityCtrl.text);
    if (q == null) return false;
    return q < _virtualAvailable;
  }

  Future<void> _save() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_expiryDate == null || _unit == null) {
      _snack(tr('unknown_error'));
      return;
    }

    final quantityValue = _parseDouble(_quantityCtrl.text) ?? 0;
    final price = _parseDouble(_priceCtrl.text);

    setState(() => _saving = true);
    try {
      await inventorySvc.updateInventoryItem(
        widget.itemId,
        UpdateInventoryItemInput(
          name: _nameCtrl.text.trim(),
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          category: _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          quantity: QuantityInput(value: quantityValue, unit: _unit!),
          price: price,
          expiryDate: _expiryDate!,
        ),
      );

      if (!mounted) return;

      if (_quantityBelowVirtual) {
        _snack(
          'note_if_new_quantity_less_than_virtual_no_effect'.tr(),
        );
      } else {
        _snack('saved'.tr());
      }

      context.pop(true);
    } catch (e) {
      _snack('error_occurred'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('delete_item_confirm_title'.tr()),
          content: Text('delete_item_confirm_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await inventorySvc.deleteInventoryItem(widget.itemId);
      if (!mounted) return;
      _snack('deleted'.tr());
      context.pop(true);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('edit_item'.tr())),
      body: SafeArea(
        child: FutureBuilder<InventoryItem>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('error_occurred'.tr(args: [snap.error?.toString() ?? 'unknown'.tr()])));
            }

            final item = snap.data!;
            final unitLabel = _enumLabel(_unit ?? item.quantity.unit);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _InfoCard(
                  title: item.name,
                  subtitle: 'ID: ${widget.itemId}',
                ),
                const SizedBox(height: 12),

                _HintCard(
                  icon: Icons.cloud_outlined,
                  title:
                      '${'virtual_quantity'.tr()}: ${_fmtNum(_virtualAvailable)} $unitLabel',
                  message:
                      'if_new_quantity_less_than_virtual_no_effect'.tr(),
                  highlight: _quantityBelowVirtual,
                ),
                const SizedBox(height: 12),

                Material(
                  color: cs.surfaceContainerLowest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 160),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _Field(
                            controller: _nameCtrl,
                            label: tr('fridge_item'),
                            hint: 'Name',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'required'.tr();
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _brandCtrl,
                                  label: tr('brand'),
                                  hint: 'optional'.tr(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Field(
                                  controller: _categoryCtrl,
                                  label: tr('category'),
                                  hint: 'optional'.tr(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _quantityCtrl,
                                  label: tr('quantity'),
                                  hint: '0',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final d = _parseDouble(v ?? '');
                                    if (d == null) return 'Required';
                                    if (d < 0) return 'Must be >= 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ReadOnlyPill(
                                  label: 'unit'.tr(),
                                  value: unitLabel,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _priceCtrl,
                                  label: tr('price'),
                                  hint: 'optional'.tr(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateField(
                                  label: tr('expire'),
                                  value: _expiryDate == null
                                      ? '—'
                                      : _fmtDate(_expiryDate!),
                                  onTap: _pickExpiryDate,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_saving || _deleting) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'saving'.tr() : 'save'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_saving || _deleting) ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(_deleting ? 'deleting'.tr() : 'delete'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(
                            color: cs.error.withValues(alpha: 200),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 160)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool highlight;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final border = highlight
        ? cs.tertiary.withValues(alpha: 220)
        : cs.outlineVariant.withValues(alpha: 160);

    return Material(
      color: cs.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: cs.surfaceContainer,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 160),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.primary.withValues(alpha: 220),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 160)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ReadOnlyPill extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 160)),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
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
