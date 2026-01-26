import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/models/enums.dart';
import 'package:mocc/service/inventory_service.dart';
import 'package:mocc/service/shopping_service.dart';
import 'package:uuid/uuid.dart';

class AddShoppingTripView extends ConsumerStatefulWidget {
  final Map<String, dynamic>? entry;

  const AddShoppingTripView({super.key, this.entry});

  @override
  ConsumerState<AddShoppingTripView> createState() =>
      _AddShoppingTripViewState();
}

class _AddShoppingTripViewState extends ConsumerState<AddShoppingTripView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _storeNameController;
  late TextEditingController _totalAmountController;
  late DateTime _selectedDate;

  final List<Map<String, dynamic>> _items = [];
  bool _isImported = false;

  final String _addMutation = ShoppingService.addShoppingHistoryMutation;
  final String _updateMutation = ShoppingService.updateShoppingHistoryMutation;
  final String _importMutation =
      ShoppingService.importShoppingHistoryToFridgeMutation;
  final String _suggestionsQuery = ShoppingService.getSuggestionsQuery;

  @override
  void initState() {
    super.initState();
    _isImported = widget.entry?['isImported'] == true;
    _storeNameController = TextEditingController(
      text: widget.entry?['storeName'] ?? '',
    );
    _totalAmountController = TextEditingController(
      text: widget.entry?['totalAmount']?.toString() ?? '',
    );

    if (widget.entry != null && widget.entry!['date'] != null) {
      _selectedDate =
          DateTime.tryParse(widget.entry!['date']) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    if (widget.entry != null && widget.entry!['itemsSnapshot'] != null) {
      for (var item in widget.entry!['itemsSnapshot']) {
        final nameVal = item['name'];
        final priceVal = item['price'];
        final qtyVal = item['quantity'];
        final catVal = item['category'];
        final brandVal = item['brand'];
        final expiryDateVal = item['expiryDate'];
        final expiryTypeVal = item['expiryType'];

        _items.add({
          'id': const Uuid().v4(),
          'name': nameVal is String ? nameVal : (nameVal?.toString() ?? ''),
          'price': priceVal?.toString() ?? '0.0',
          'quantity': qtyVal?.toString() ?? '1',
          'category': catVal is String ? catVal : (catVal?.toString() ?? ''),
          'brand': brandVal is String ? brandVal : (brandVal?.toString() ?? ''),
          'expiryDate': expiryDateVal is String
              ? (DateTime.tryParse(expiryDateVal) ??
                    DateTime.now().add(const Duration(days: 7)))
              : DateTime.now().add(const Duration(days: 7)),
          'expiryType': _parseExpiryType(expiryTypeVal),
          'unit': item['unit'] != null
              ? Unit.values.firstWhere(
                  (e) =>
                      e.name.toUpperCase() ==
                      item['unit'].toString().toUpperCase(),
                  orElse: () => Unit.pz,
                )
              : Unit.pz,
        });
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  ExpiryType _parseExpiryType(dynamic value) {
    if (value == null) return ExpiryType.bestBefore;
    if (value is ExpiryType) return value;
    if (value is String) return ExpiryType.fromJson(value);
    // Handle case where value might be a map with unexpected structure
    return ExpiryType.bestBefore;
  }

  String _formatExpiryDate(dynamic value) {
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('yyyy-MM-dd').format(parsed);
      }
      return value;
    }
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().add(const Duration(days: 7)));
  }

  String _safeString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return defaultValue;
  }

  void _addItem() {
    if (_isImported) return;
    setState(() {
      _items.add({
        'id': const Uuid().v4(),
        'name': '',
        'price': '0.0',
        'quantity': '1',
        'category': '',
        'brand': '',
        'expiryDate': DateTime.now().add(const Duration(days: 7)),
        'expiryType': ExpiryType.bestBefore,
        'unit': Unit.pz,
      });
    });
  }

  void _removeItem(int index) {
    if (_isImported) return;
    setState(() {
      _items.removeAt(index);
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    double total = 0;
    for (var item in _items) {
      final price = double.tryParse(item['price'] ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity'] ?? '1') ?? 1.0;
      total += price * qty;
    }
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  Map<String, dynamic> _buildInput() {
    final itemsInput = _items
        .map(
          (item) => {
            'name': item['name'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'quantity': double.tryParse(item['quantity'].toString()) ?? 1.0,
            'category': item['category'],
            'brand': item['brand'],
            'expiryDate': (item['expiryDate'] as DateTime).toIso8601String(),
            'expiryType': (item['expiryType'] as ExpiryType).toJson(),
            'unit': (item['unit'] as Unit).name.toUpperCase(),
          },
        )
        .toList();

    return {
      'date': _selectedDate.toIso8601String(),
      'storeName': _storeNameController.text,
      'totalAmount': double.tryParse(_totalAmountController.text) ?? 0.0,
      'items': itemsInput,
      'currency': 'EUR',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;
    final readOnly = _isImported;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'edit_shopping_trip'.tr() : 'new_shopping_trip'.tr(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: Query(
        options: QueryOptions(
          document: gql(_suggestionsQuery),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
        builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
          var suggestedStores = <String>[];
          var suggestedCategories = <String>[];
          var suggestedNames = <String>[];
          var suggestedBrands = <String>[];

          if (result.data != null) {
            try {
              final historyData = result.data!['shoppingHistory'];
              final fridgeData = result.data!['myFridge'];

              final history = historyData is List ? historyData : [];
              final fridgeItems = fridgeData is Map
                  ? (fridgeData['items'] is List ? fridgeData['items'] : [])
                  : [];

              final stores = <String>{};
              final cats = <String>{};
              final names = <String>{};
              final brands = <String>{};

              for (var h in history) {
                if (h is! Map) continue;
                final storeName = h['storeName'];
                if (storeName is String && storeName.isNotEmpty) {
                  stores.add(storeName);
                }
                final itemsSnapshot = h['itemsSnapshot'];
                if (itemsSnapshot is List) {
                  for (var i in itemsSnapshot) {
                    if (i is! Map) continue;
                    final itemName = i['name'];
                    final itemCategory = i['category'];
                    final itemBrand = i['brand'];
                    if (itemName is String && itemName.isNotEmpty) {
                      names.add(itemName);
                    }
                    if (itemCategory is String && itemCategory.isNotEmpty) {
                      cats.add(itemCategory);
                    }
                    if (itemBrand is String && itemBrand.isNotEmpty) {
                      brands.add(itemBrand);
                    }
                  }
                }
              }
              for (var f in fridgeItems) {
                if (f is! Map) continue;
                final fridgeName = f['name'];
                final fridgeCategory = f['category'];
                final fridgeBrand = f['brand'];
                if (fridgeName is String && fridgeName.isNotEmpty) {
                  names.add(fridgeName);
                }
                if (fridgeCategory is String && fridgeCategory.isNotEmpty) {
                  cats.add(fridgeCategory);
                }
                if (fridgeBrand is String && fridgeBrand.isNotEmpty) {
                  brands.add(fridgeBrand);
                }
              }
              suggestedStores = stores.toList();
              suggestedCategories = cats.toList();
              suggestedNames = names.toList();
              suggestedBrands = brands.toList();
            } catch (e) {
              debugPrint('Error parsing suggestions: $e');
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isImported)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.error),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: cs.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'cannot_edit_imported'.tr(),
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Store Name AutoComplete
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        initialValue: TextEditingValue(
                          text: _storeNameController.text,
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return suggestedStores.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          _storeNameController.text = selection;
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              textEditingController.addListener(() {
                                if (_storeNameController.text !=
                                    textEditingController.text) {
                                  _storeNameController.text =
                                      textEditingController.text;
                                }
                              });
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: '${'store_name'.tr()}*',
                                  border: const OutlineInputBorder(),
                                ),
                                enabled: !readOnly,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'required'.tr()
                                    : null,
                              );
                            },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: readOnly
                        ? null
                        : () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate.isAfter(DateTime.now())
                                  ? DateTime.now()
                                  : _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null && picked != _selectedDate) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '${'date'.tr()}*',
                        border: const OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('total_amount'.tr(), style: textTheme.bodyLarge),
                        Text(
                          '${_totalAmountController.text} ${'eur'.tr()}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${'items'.tr()} *', style: textTheme.titleLarge),
                      if (!readOnly)
                        IconButton(
                          onPressed: _addItem,
                          icon: Icon(Icons.add_circle, color: cs.primary),
                        ),
                    ],
                  ),
                  const Divider(),

                  // Items List
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Autocomplete<String>(
                                        initialValue: TextEditingValue(
                                          text: _safeString(item['name']),
                                        ),
                                        optionsBuilder:
                                            (
                                              TextEditingValue textEditingValue,
                                            ) {
                                              if (textEditingValue.text == '') {
                                                return const Iterable<
                                                  String
                                                >.empty();
                                              }
                                              return suggestedNames.where((
                                                String option,
                                              ) {
                                                return option
                                                    .toLowerCase()
                                                    .contains(
                                                      textEditingValue.text
                                                          .toLowerCase(),
                                                    );
                                              });
                                            },
                                        onSelected: (String selection) {
                                          item['name'] = selection;
                                        },
                                        fieldViewBuilder:
                                            (
                                              context,
                                              textEditingController,
                                              focusNode,
                                              onFieldSubmitted,
                                            ) {
                                              textEditingController.addListener(
                                                () {
                                                  item['name'] =
                                                      textEditingController
                                                          .text;
                                                },
                                              );
                                              return TextFormField(
                                                controller:
                                                    textEditingController,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  labelText: '${'name'.tr()}*',
                                                ),
                                                enabled: !readOnly,
                                                validator: (val) =>
                                                    (val == null || val.isEmpty)
                                                    ? 'required'.tr()
                                                    : null,
                                              );
                                            },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!readOnly)
                                  IconButton(
                                    icon: Icon(Icons.delete, color: cs.error),
                                    onPressed: () => _removeItem(index),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _safeString(
                                      item['price'],
                                      '0.0',
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '${'price'.tr()}*',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d*'),
                                      ),
                                    ],
                                    enabled: !readOnly,
                                    onChanged: (val) {
                                      item['price'] = val;
                                      _recalculateTotal();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _safeString(
                                      item['quantity'],
                                      '1',
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '${'quantity'.tr()}*',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d*'),
                                      ),
                                    ],
                                    enabled: !readOnly,
                                    onChanged: (val) {
                                      item['quantity'] = val;
                                      _recalculateTotal();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<Unit>(
                                    value: item['unit'] as Unit,
                                    decoration: InputDecoration(
                                      labelText: '${'unit'.tr()}*',
                                    ),
                                    items: Unit.values.map((unit) {
                                      return DropdownMenuItem(
                                        value: unit,
                                        child: Text(unit.name.toUpperCase()),
                                      );
                                    }).toList(),
                                    onChanged: readOnly
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(() {
                                                item['unit'] = val;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Autocomplete<String>(
                                        initialValue: TextEditingValue(
                                          text: _safeString(item['category']),
                                        ),
                                        optionsBuilder:
                                            (
                                              TextEditingValue textEditingValue,
                                            ) {
                                              if (textEditingValue.text == '') {
                                                return const Iterable<
                                                  String
                                                >.empty();
                                              }
                                              return suggestedCategories.where((
                                                String option,
                                              ) {
                                                return option
                                                    .toLowerCase()
                                                    .contains(
                                                      textEditingValue.text
                                                          .toLowerCase(),
                                                    );
                                              });
                                            },
                                        onSelected: (String selection) {
                                          item['category'] = selection;
                                        },
                                        fieldViewBuilder:
                                            (
                                              context,
                                              textEditingController,
                                              focusNode,
                                              onFieldSubmitted,
                                            ) {
                                              textEditingController.addListener(
                                                () {
                                                  item['category'] =
                                                      textEditingController
                                                          .text;
                                                },
                                              );
                                              return TextFormField(
                                                controller:
                                                    textEditingController,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  labelText: 'category'.tr(),
                                                ),
                                                enabled: !readOnly,
                                              );
                                            },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Autocomplete<String>(
                                        initialValue: TextEditingValue(
                                          text: _safeString(item['brand']),
                                        ),
                                        optionsBuilder:
                                            (
                                              TextEditingValue textEditingValue,
                                            ) {
                                              if (textEditingValue.text == '') {
                                                return const Iterable<
                                                  String
                                                >.empty();
                                              }
                                              return suggestedBrands.where((
                                                String option,
                                              ) {
                                                return option
                                                    .toLowerCase()
                                                    .contains(
                                                      textEditingValue.text
                                                          .toLowerCase(),
                                                    );
                                              });
                                            },
                                        onSelected: (String selection) {
                                          item['brand'] = selection;
                                        },
                                        fieldViewBuilder:
                                            (
                                              context,
                                              textEditingController,
                                              focusNode,
                                              onFieldSubmitted,
                                            ) {
                                              textEditingController.addListener(
                                                () {
                                                  item['brand'] =
                                                      textEditingController
                                                          .text;
                                                },
                                              );
                                              return TextFormField(
                                                controller:
                                                    textEditingController,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  labelText: 'brand'.tr(),
                                                ),
                                                enabled: !readOnly,
                                              );
                                            },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: readOnly
                                        ? null
                                        : () async {
                                            final DateTime?
                                            picked = await showDatePicker(
                                              context: context,
                                              initialDate: item['expiryDate'],
                                              firstDate: DateTime.now()
                                                  .subtract(
                                                    const Duration(days: 365),
                                                  ),
                                              lastDate: DateTime.now().add(
                                                const Duration(days: 3650),
                                              ),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                item['expiryDate'] = picked;
                                              });
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: '${'expiry_date'.tr()}*',
                                      ),
                                      child: Text(
                                        _formatExpiryDate(item['expiryDate']),
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<ExpiryType>(
                                    initialValue: item['expiryType'],
                                    decoration: InputDecoration(
                                      labelText: '${'expire'.tr()}*',
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: ExpiryType.bestBefore,
                                        child: Text('best_before'.tr()),
                                      ),
                                      DropdownMenuItem(
                                        value: ExpiryType.expiration,
                                        child: Text('expiry_date'.tr()),
                                      ),
                                    ],
                                    onChanged: readOnly
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(() {
                                                item['expiryType'] = val;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  if (isEditing && !_isImported)
                    Mutation(
                      options: MutationOptions(
                        document: gql(_importMutation),
                        onCompleted: (data) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('history_imported'.tr())),
                          );
                          setState(() {
                            _isImported = true;
                          });
                          ref.read(fridgeRefreshProvider.notifier).refresh();
                          ref.read(shoppingRefreshProvider.notifier).refresh();
                        },
                      ),
                      builder: (RunMutation runMutation, QueryResult? result) {
                        return OutlinedButton.icon(
                          onPressed: () {
                            runMutation({'id': widget.entry!['id']});
                          },
                          icon: const Icon(Icons.file_download),
                          label: Text('import_to_fridge'.tr()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: !readOnly
          ? Padding(
              padding: const EdgeInsets.only(bottom: 110),
              child: Mutation(
                options: MutationOptions(
                  document: gql(isEditing ? _updateMutation : _addMutation),
                  onCompleted: (data) {
                    ref.read(shoppingRefreshProvider.notifier).refresh();
                    Navigator.of(context).pop();
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  },
                ),
                builder: (RunMutation runMutation, QueryResult? result) {
                  return FloatingActionButton.extended(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final input = _buildInput();
                        if (isEditing) {
                          runMutation({
                            'id': widget.entry!['id'],
                            'input': input,
                          });
                        } else {
                          runMutation({'input': input});
                        }
                      }
                    },
                    label: Text(
                      'confirm_and_save'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.check),
                  );
                },
              ),
            )
          : null,
    );
  }
}
