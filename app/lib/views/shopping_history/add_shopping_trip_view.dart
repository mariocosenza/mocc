import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/models/enums.dart';
import 'package:mocc/service/inventory_service.dart';
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
  String? _stagingSessionId;
  String? _receiptImageUrl;

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
      // Use entry ID as staging session to enable Scan button
      _stagingSessionId = widget.entry!['id']?.toString();

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
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForStagingSession();
      });
    }
  }

  Future<void> _checkForStagingSession() async {
    try {
      final shoppingService = ref.read(shoppingServiceProvider);
      final session = await shoppingService.getCurrentStagingSession();

      if (session != null && mounted) {
        setState(() {
          if (session.detectedStore != null) {
            _storeNameController.text = session.detectedStore!;
          }
          if (session.detectedTotal != null) {
            _totalAmountController.text = session.detectedTotal!
                .toStringAsFixed(2);
          }

          for (final item in session.items) {
            _items.add({
              'id': item.id,
              'name': item.name,
              'price': item.detectedPrice?.toString() ?? '0.0',
              'quantity': item.quantity?.toString() ?? '1',
              'category': '',
              'brand': '',
              'expiryDate': DateTime.now().add(const Duration(days: 7)),
              'expiryType': ExpiryType.bestBefore,
              'unit': Unit.pz,
            });
          }
        });

        if (mounted) {
          _stagingSessionId = session.id;
          _receiptImageUrl = session.receiptImageUrl;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('receipt_data_loaded'.tr())));
        }
      }
    } catch (e) {
      debugPrint('Error checking staging session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading receipt: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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

    // Ensure we have a session
    String sessionId = _stagingSessionId ?? '';
    if (sessionId.isEmpty) {
      try {
        // Create session with current receipt image if any, or null
        final session = await shoppingService.createStagingSession(null);
        sessionId = session.id;
        setState(() {
          _stagingSessionId = sessionId;
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
    }

    try {
      // 1. Add placeholder item to backend staging
      final placeholderName = 'Analisi in corso...';
      final item = await shoppingService.addItemToStaging(
        sessionId,
        placeholderName,
        1,
      );

      // Generate SAS token for path: product-labels/{uid}/{sessionId}/{itemId}/label.jpg
      final relativePath = '$sessionId/${item.id}/label.jpg';
      final sasUrl = await shoppingService.generateUploadSasToken(
        relativePath,
        'PRODUCT_LABEL',
      );

      // 3. Upload image
      final imageBytes = await image.readAsBytes();
      debugPrint('[LabelUpload] SAS URL: $sasUrl');
      debugPrint('[LabelUpload] Image size: ${imageBytes.length} bytes');

      final response = await http.put(
        Uri.parse(sasUrl),
        body: imageBytes,
        headers: {'x-ms-blob-type': 'BlockBlob', 'Content-Type': 'image/jpeg'},
      );

      debugPrint('[LabelUpload] HTTP Status: ${response.statusCode}');
      debugPrint('[LabelUpload] Response Body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }

      if (!mounted) return;

      // 4. Update local list with placeholder
      final localItem = {
        'id': item.id,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('upload_success'.tr())));

      // 5. Poll for results
      _pollForItemUpdate(sessionId, item.id, localItem);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pollForItemUpdate(
    String sessionId,
    String itemId,
    Map<String, dynamic> localItem,
  ) async {
    final shoppingService = ref.read(shoppingServiceProvider);
    int attempts = 0;
    const maxAttempts = 15; // 30 seconds total (2s delay)

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;

      try {
        final session = await shoppingService.getCurrentStagingSession();
        if (session == null) break;

        final updatedItem = session.items.firstWhere(
          (i) => i.id == itemId,
          orElse: () => throw Exception('Item not found'),
        );

        if (updatedItem.name != 'Analisi in corso...') {
          if (mounted) {
            setState(() {
              localItem['name'] = updatedItem.name;
              localItem['price'] =
                  updatedItem.detectedPrice?.toString() ?? '0.0';
              if (updatedItem.quantity != null) {
                localItem['quantity'] = updatedItem.quantity.toString();
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
      if (_receiptImageUrl != null) 'receiptImageUrl': _receiptImageUrl,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_receiptImageUrl != null &&
                      _receiptImageUrl!.isNotEmpty &&
                      _receiptImageUrl!.startsWith('http'))
                    GestureDetector(
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: _receiptImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.receipt_long,
                                      size: 40,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tap to view',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${'items'.tr()} *', style: textTheme.titleLarge),
                      if (!readOnly)
                        Row(
                          children: [
                            IconButton(
                              // Scan button is always enabled.
                              // Session is created automatically if needed inside _scanProductLabel.
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
                                    initialValue: item['unit'] as Unit,
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
                                    isExpanded: true,
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
                  const SizedBox(height: 24),
                  if (!readOnly)
                    Mutation(
                      options: MutationOptions(
                        document: gql(
                          isEditing ? _updateMutation : _addMutation,
                        ),
                        onCompleted: (data) {
                          if (_stagingSessionId != null) {
                            ref
                                .read(shoppingServiceProvider)
                                .discardStagingSession(_stagingSessionId!);
                          }
                          ref.read(shoppingRefreshProvider.notifier).refresh();
                          context.go('/app/shopping');
                        },
                        onError: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        },
                      ),
                      builder: (RunMutation runMutation, QueryResult? result) {
                        return FilledButton.icon(
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
                          style: FilledButton.styleFrom(
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
    );
  }
}
