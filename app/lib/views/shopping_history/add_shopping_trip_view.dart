import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/models/enums.dart';
import 'package:mocc/service/shopping_service.dart';
import 'package:mocc/service/providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  String? _historyId; // Replaces _stagingSessionId
  ShoppingHistoryStatus _currentStatus = ShoppingHistoryStatus.inStaging;
  String? _receiptImageUrl;
  String _currency = 'EUR';

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
    _currency = widget.entry?['currency'] ?? 'EUR';

    if (widget.entry != null && widget.entry!['date'] != null) {
      _selectedDate =
          DateTime.tryParse(widget.entry!['date']) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
      // Load user preferences for new entries
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserPreferences();
      });
    }

    if (widget.entry != null && widget.entry!['status'] != null) {
      _currentStatus = ShoppingHistoryStatus.fromJson(
        widget.entry!['status'].toString(),
      );
    }

    _receiptImageUrl = widget.entry?['receiptImageUrl'];
    _historyId = widget.entry?['id']?.toString();

    if (widget.entry != null && widget.entry!['itemsSnapshot'] != null) {
      for (var item in widget.entry!['itemsSnapshot']) {
        final nameVal = item['name'];
        final priceVal = item['price'];
        final qtyVal = item['quantity'];
        final catVal = item['category'];
        final brandVal = item['brand'];
        final expiryDateVal = item['expiryDate'];
        final expiryTypeVal = item['expiryType'];
        final unitVal = item['unit'];
        final idVal = item['id']; // Now HistoryItem has ID

        _items.add({
          'id': idVal ?? const Uuid().v4(),
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
          'unit': unitVal != null
              ? Unit.values.firstWhere(
                  (e) =>
                      e.name.toUpperCase() == unitVal.toString().toUpperCase(),
                  orElse: () => Unit.pz,
                )
              : Unit.pz,
        });
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final userService = ref.read(userServiceProvider);
      final prefs = await userService.getUserPreferences();
      if (mounted) {
        setState(() {
          _currency = prefs.currency.toJson();
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  String get _currencySymbol => _currency == 'USD' ? '\$' : '€';

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
    return ExpiryType.bestBefore;
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
      _recalculateTotal();
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
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
      total += price * qty;
    }
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  Map<String, dynamic> _buildInput({required ShoppingHistoryStatus status}) {
    final dateStr = _selectedDate.toIso8601String();
    final storeName = _storeNameController.text.trim();
    final totalAmount = double.tryParse(_totalAmountController.text) ?? 0.0;
    // Map items
    final itemsMapped = _items.map((i) {
      return {
        'id': i['id'], // Ensure ID is passed back if updating
        'name': i['name'],
        'price': double.tryParse(i['price'].toString()) ?? 0.0,
        'quantity': double.tryParse(i['quantity'].toString()) ?? 1.0,
        'category': i['category'],
        'brand': i['brand'],
        'expiryDate': (i['expiryDate'] as DateTime).toIso8601String(),
        'expiryType':
            (i['expiryType'] as ExpiryType?)?.toJson() ?? 'BEST_BEFORE',
        'unit': (i['unit'] as Unit?)?.toJson() ?? 'PZ',
      };
    }).toList();

    return {
      'date': dateStr,
      'storeName': storeName,
      'totalAmount': totalAmount,
      'currency': _currency,
      'status': status.toJson(),
      'items': itemsMapped,
      'receiptImageUrl': _receiptImageUrl,
    };
  }

  Future<void> _save() async {
    // Basic validation
    if (_items.isEmpty && _currentStatus == ShoppingHistoryStatus.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_items_to_start_tracking'.tr())),
      );
      return;
    }

    final input = _buildInput(status: _currentStatus);

    try {
      final shoppingService = ref.read(shoppingServiceProvider);
      if (_historyId == null) {
        // Create
        await shoppingService.addShoppingHistoryJson(input);
      } else {
        // Update
        await shoppingService.updateShoppingHistoryJson(_historyId!, input);
      }

      if (mounted) {
        if (_currentStatus == ShoppingHistoryStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('history_saved_and_items_added'.tr())),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to Staging')));
        }
        ref.read(shoppingRefreshProvider.notifier).refresh();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/app/shopping');
        }
      }
    } catch (e) {
      debugPrint('Error saving shopping history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_occurred'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  Future<void> _scanProductLabel() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;
    if (!mounted) return;

    final shoppingService = ref.read(shoppingServiceProvider);

    // Ensure we have a history entry (= session)
    String historyId = _historyId ?? '';

    // 1. Create entry if not exists
    if (historyId.isEmpty) {
      try {
        final input = _buildInput(status: _currentStatus);
        historyId = await shoppingService.addShoppingHistoryJson(
          input,
        ); // Use Json method
        setState(() {
          _historyId = historyId;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Update existing to ensure items are saved before scanning label (so we don't lose them)
      try {
        final input = _buildInput(status: _currentStatus);
        await shoppingService.updateShoppingHistoryJson(historyId, input);
      } catch (e) {
        debugPrint("Failed to save state before scan: $e");
        // Continue anyway?
      }
    }

    try {
      // 2. Add placeholder item locally
      final placeholderName = 'analysis_in_progress'.tr();
      final itemId = const Uuid().v4();
      final localItem = {
        'id': itemId,
        'name': placeholderName,
        'price': '0.0',
        'quantity': '1',
        'category': '',
        'brand': '',
        'expiryDate': DateTime.now().add(const Duration(days: 7)),
        'expiryType': ExpiryType.bestBefore,
        'unit': Unit.pz,
      };

      setState(() {
        _items.add(localItem);
      });

      // Save again to persist placeholder (needed for function to update it? No, function uses ID)
      // Wait, if I add item locally, I must save it to backend so backend has this Item ID.
      // ShoppingHistory update replaces items. So I must save it.
      final input = _buildInput(status: _currentStatus);
      await shoppingService.updateShoppingHistoryJson(historyId, input);

      // 3. Generate SAS token
      // Path: historyId/itemId/label.jpg
      final relativePath = '$historyId/$itemId/label.jpg';
      final sasUrl = await shoppingService.generateUploadSasToken(
        relativePath,
        'PRODUCT_LABEL',
      );

      // 4. Upload image
      final imageBytes = await image.readAsBytes();
      debugPrint('[LabelUpload] SAS URL: $sasUrl');

      final response = await http.put(
        Uri.parse(sasUrl),
        body: imageBytes,
        headers: {'x-ms-blob-type': 'BlockBlob', 'Content-Type': 'image/jpeg'},
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('upload_success'.tr())));

      // 5. Poll for results
      _pollForItemUpdate(historyId, itemId, localItem);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pollForItemUpdate(
    String historyId,
    String itemId,
    Map<String, dynamic> localItem,
  ) async {
    final shoppingService = ref.read(shoppingServiceProvider);
    int attempts = 0;
    const maxAttempts = 15; // 30 seconds

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;

      try {
        final entry = await shoppingService.getShoppingHistoryEntry(historyId);
        if (entry == null) throw Exception("Entry not found");

        final updatedItem = entry.itemsSnapshot.firstWhere(
          (i) => i.id == itemId,
          orElse: () => throw Exception("Item not found"),
        );

        if (updatedItem.name != 'analysis_in_progress'.tr()) {
          if (mounted) {
            setState(() {
              // Find index of localItem in _items (it might have moved if sorted, but we look by ID)
              final index = _items.indexWhere((i) => i['id'] == itemId);
              if (index != -1) {
                _items[index]['name'] = updatedItem.name;
                _items[index]['price'] = updatedItem.price?.toString() ?? '0.0';
                _items[index]['quantity'] =
                    updatedItem.quantity?.toString() ?? '1';
                if (updatedItem.brand != null) {
                  _items[index]['brand'] = updatedItem.brand;
                }
                if (updatedItem.category != null) {
                  _items[index]['category'] = updatedItem.category;
                }
                // Unit, expiry etc?
              }
              _recalculateTotal();
            });
          }
          break;
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    }

    // Handle timeout or failure: remove temp item if it's still there
    if (mounted && attempts >= maxAttempts) {
      if (mounted) {
        setState(() {
          final index = _items.indexWhere((i) => i['id'] == itemId);
          if (index != -1) {
            _items.removeAt(index);
            _recalculateTotal();

            // Persist the removal to backend
            try {
              final input = _buildInput(status: _currentStatus);
              ref
                  .read(shoppingServiceProvider)
                  .updateShoppingHistoryJson(_historyId!, input);
            } catch (e) {
              debugPrint("Failed to sync removal of failed scan item: $e");
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('scan_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importToFridge() async {
    if (_historyId == null) return;

    // Check for scanning items
    final hasScanning = _items.any(
      (i) => i['name'] == 'analysis_in_progress'.tr(),
    );
    // Check 0: Check for scanning items
    if (hasScanning) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('import_blocked_scanning'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check 1: Store Name required
    if (_storeNameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'store_name_required'.tr(),
            ), // Ensure this key exists or use a literal fallback temporarily
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check 2: Must be Saved
    if (_currentStatus != ShoppingHistoryStatus.saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('save_before_import'.tr()), // "Save before importing"
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final shoppingService = ref.read(shoppingServiceProvider);
    try {
      await shoppingService.importShoppingHistoryToFridge(_historyId!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('imported_successfully'.tr())));
        ref.read(shoppingRefreshProvider.notifier).refresh();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/app/shopping');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteShoppingTrip() async {
    if (_historyId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_history_confirm'.tr()),
        content: Text(
          'delete_item_confirm_message'.tr(),
        ), // Reuse item confirm or add new key? Using existing for now.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final shoppingService = ref.read(shoppingServiceProvider);
    try {
      await shoppingService.deleteShoppingHistory(_historyId!);
      if (mounted) {
        ref.read(shoppingRefreshProvider.notifier).refresh();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/app/shopping');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app/shopping');
            }
          },
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'delete'.tr(),
              color: Colors.red,
              onPressed: _deleteShoppingTrip,
            ),
          if (isEditing && !_isImported)
            IconButton(
              icon: const Icon(Icons.kitchen),
              tooltip: 'import_to_fridge'.tr(),
              onPressed: _importToFridge,
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      bottomNavigationBar: !readOnly
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text('save'.tr()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            )
          : null,
      body: Query(
        options: QueryOptions(
          document: gql(_suggestionsQuery),
          fetchPolicy: FetchPolicy.cacheAndNetwork,
        ),
        builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
          // ... (Same suggestions logic)
          var suggestedStores = <String>[];
          if (result.data != null) {
            // ... Simplified for brevity, assume logic copied or kept
            try {
              final historyData = result.data!['shoppingHistory'];
              if (historyData is List) {
                for (var h in historyData) {
                  if (h is Map && h['storeName'] is String) {
                    suggestedStores.add(h['storeName']);
                  }
                }
              }
            } catch (_) {}
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_receiptImageUrl != null && _receiptImageUrl!.isNotEmpty)
                    _buildReceiptPreview(cs),

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

                  InkWell(
                    onTap: readOnly
                        ? null
                        : () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
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

                  // Total Amount
                  TextFormField(
                    controller: _totalAmountController,
                    decoration: InputDecoration(
                      labelText: 'total_amount'.tr(),
                      border: const OutlineInputBorder(),
                      suffixText: _currency,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: readOnly,
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${'items'.tr()} *', style: textTheme.titleLarge),
                      if (!readOnly)
                        Row(
                          children: [
                            IconButton(
                              onPressed: _scanProductLabel,
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'scan_label'.tr(),
                              color: cs.secondary,
                            ),
                            IconButton(
                              onPressed: _addItem,
                              icon: Icon(Icons.add_circle, color: cs.primary),
                              tooltip: 'add_manual'.tr(),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(),

                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      key: ValueKey(item['id']),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child:
                                      item['name'] ==
                                          'analysis_in_progress'.tr()
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'processing'.tr(),
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        )
                                      : TextFormField(
                                          initialValue: item['name'],
                                          decoration: InputDecoration(
                                            labelText: 'item_name'.tr(),
                                          ),
                                          onChanged: (val) =>
                                              item['name'] = val,
                                          readOnly: readOnly,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item['price'].toString(),
                                    decoration: InputDecoration(
                                      labelText: 'price'.tr(),
                                      suffixText: _currencySymbol,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      item['price'] = val;
                                      _recalculateTotal(); // Recalc when price changes
                                    },
                                    readOnly: readOnly,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: item['brand'],
                                    decoration: InputDecoration(
                                      labelText: 'brand'.tr(),
                                    ),
                                    onChanged: (val) => item['brand'] = val,
                                    readOnly: readOnly,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item['category'],
                                    decoration: InputDecoration(
                                      labelText: 'category'.tr(),
                                    ),
                                    onChanged: (val) => item['category'] = val,
                                    readOnly: readOnly,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item['quantity'].toString(),
                                    decoration: InputDecoration(
                                      labelText: 'quantity'.tr(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      item['quantity'] = val;
                                      _recalculateTotal();
                                    },
                                    readOnly: readOnly,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<Unit>(
                                    key: ValueKey('unit_${item['unit']}'),
                                    initialValue:
                                        item['unit'] as Unit? ?? Unit.pz,
                                    decoration: InputDecoration(
                                      labelText: 'unit'.tr(),
                                    ),
                                    items: Unit.values.map((u) {
                                      return DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                          'unit_enum.${u.name.toLowerCase()}'
                                              .tr(),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: readOnly
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(
                                                () => item['unit'] = val,
                                              );
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
                                  flex: 2,
                                  child: InkWell(
                                    onTap: readOnly
                                        ? null
                                        : () async {
                                            final DateTime? picked =
                                                await showDatePicker(
                                                  context: context,
                                                  initialDate:
                                                      item['expiryDate']
                                                          as DateTime? ??
                                                      DateTime.now(),
                                                  firstDate: DateTime.now()
                                                      .subtract(
                                                        const Duration(
                                                          days: 365,
                                                        ),
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
                                        labelText: 'expire'.tr(),
                                      ),
                                      child: Text(
                                        item['expiryDate'] != null
                                            ? DateFormat('yyyy-MM-dd').format(
                                                item['expiryDate'] as DateTime,
                                              )
                                            : '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<ExpiryType>(
                                    key: ValueKey(
                                      'expiry_${item['expiryType']}',
                                    ),
                                    initialValue:
                                        item['expiryType'] as ExpiryType? ??
                                        ExpiryType.bestBefore,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'type'.tr(),
                                    ),
                                    items: ExpiryType.values.map((e) {
                                      return DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          'expiry_type.${e.name.toLowerCase()}'
                                              .tr(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: readOnly
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setState(
                                                () => item['expiryType'] = val,
                                              );
                                            }
                                          },
                                  ),
                                ),
                                if (!readOnly) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptPreview(ColorScheme cs) {
    if (_receiptImageUrl == null || !_receiptImageUrl!.startsWith('http')) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: _receiptImageUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _receiptImageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.receipt),
          ),
        ),
      ),
    );
  }
}
