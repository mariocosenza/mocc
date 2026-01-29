import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/service/shopping_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum SortOption { dateDesc, dateAsc, priceDesc, priceAsc }

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  SortOption _currentSort = SortOption.dateDesc;
  final List<Map<String, dynamic>> _pendingReceipts = [];

  static const int _pageSize = 50;

  final String _query = ShoppingService.getShoppingHistoryWithStagingQuery;
  final String _deleteMutation = ShoppingService.deleteShoppingHistoryMutation;

  final GlobalKey _fabKey = GlobalKey();

  void _showAddOptions() async {
    final RenderBox? renderBox =
        _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 170,
        offset.dx + size.width,
        offset.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'camera',
          child: ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text('take_photo'.tr()),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'gallery',
          child: ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text('upload_image'.tr()),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'manual',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text('manual_entry'.tr()),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );

    if (!mounted) return;

    if (value == 'camera') {
      _scanReceipt(ImageSource.camera);
    } else if (value == 'gallery') {
      _scanReceipt(ImageSource.gallery);
    } else if (value == 'manual') {
      context.go('/app/shopping/add');
    }
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    final pendingId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _pendingReceipts.insert(0, {
        'id': pendingId,
        'date': DateTime.now().toIso8601String(),
        'storeName': 'processing_receipt'.tr(),
        'totalAmount': 0.0,
        'isProcessing': true,
      });
    });

    if (!mounted) return;
    final shoppingService = ShoppingService(GraphQLProvider.of(context).value);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final sasUrl = await shoppingService.generateUploadSasToken(
        image.name,
        'RECEIPT_SCANNING',
      );

      final response = await http.put(
        Uri.parse(sasUrl),
        body: await image.readAsBytes(),
        headers: {'x-ms-blob-type': 'BlockBlob', 'Content-Type': 'image/jpeg'},
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode}');
      }

      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            final index = _pendingReceipts.indexWhere(
              (p) => p['id'] == pendingId,
            );
            if (index != -1) {
              _pendingReceipts[index]['isProcessing'] = false;
              _pendingReceipts[index]['isReady'] = true;
              _pendingReceipts[index]['storeName'] = 'receipt_ready_tap'.tr();
            }
            ref.read(shoppingRefreshProvider.notifier).refresh();
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingReceipts.removeWhere((p) => p['id'] == pendingId);
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('error_occurred'.tr(args: [e.toString()])),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('shopping_history'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'sort_by'.tr(),
            initialValue: _currentSort,
            onSelected: (SortOption option) {
              setState(() {
                _currentSort = option;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              PopupMenuItem<SortOption>(
                value: SortOption.dateDesc,
                child: Text('sort_date_newest'.tr()),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.dateAsc,
                child: Text('sort_date_oldest'.tr()),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<SortOption>(
                value: SortOption.priceDesc,
                child: Text('sort_price_high_low'.tr()),
              ),
              PopupMenuItem<SortOption>(
                value: SortOption.priceAsc,
                child: Text('sort_price_low_high'.tr()),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton.extended(
          key: _fabKey,
          onPressed: _showAddOptions,
          label: Text('new_shopping_trip'.tr()),
          icon: const Icon(Icons.add_shopping_cart),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
      ),
      body: Query(
        key: ValueKey(ref.watch(shoppingRefreshProvider)),
        options: QueryOptions(
          document: gql(_query),
          variables: const {'limit': _pageSize, 'offset': 0},
          pollInterval: const Duration(seconds: 30),
        ),
        builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
          if (result.hasException) {
            return Center(
              child: Text(
                'error_occurred'.tr(args: [result.exception.toString()]),
                style: TextStyle(color: cs.error),
              ),
            );
          }

          if (result.isLoading && result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          List entries = List.from(result.data?['shoppingHistory'] ?? []);
          final stagingSession = result.data?['currentStagingSession'];

          if (entries.isEmpty &&
              _pendingReceipts.isEmpty &&
              stagingSession == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('no_entries_yet'.tr(), style: textTheme.bodyLarge),
                ],
              ),
            );
          }

          entries.sort((a, b) {
            switch (_currentSort) {
              case SortOption.dateDesc:
                final dateA = DateTime.tryParse(a['date']) ?? DateTime(0);
                final dateB = DateTime.tryParse(b['date']) ?? DateTime(0);
                return dateB.compareTo(dateA);
              case SortOption.dateAsc:
                final dateA = DateTime.tryParse(a['date']) ?? DateTime(0);
                final dateB = DateTime.tryParse(b['date']) ?? DateTime(0);
                return dateA.compareTo(dateB);
              case SortOption.priceDesc:
                final priceA = (a['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final priceB = (b['totalAmount'] as num?)?.toDouble() ?? 0.0;
                return priceB.compareTo(priceA);
              case SortOption.priceAsc:
                final priceA = (a['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final priceB = (b['totalAmount'] as num?)?.toDouble() ?? 0.0;
                return priceA.compareTo(priceB);
            }
          });

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                if (fetchMore != null) {
                  fetchMore(
                    FetchMoreOptions(
                      variables: {'offset': entries.length, 'limit': _pageSize},
                      updateQuery: (previousResultData, fetchMoreResultData) {
                        final List<dynamic> repos = [
                          ...previousResultData?['shoppingHistory']
                              as List<dynamic>,
                          ...fetchMoreResultData?['shoppingHistory']
                              as List<dynamic>,
                        ];
                        fetchMoreResultData?['shoppingHistory'] = repos;
                        return fetchMoreResultData;
                      },
                    ),
                  );
                }
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount:
                  (result.isLoading ? 1 : 0) +
                  _pendingReceipts.length +
                  (stagingSession != null ? 1 : 0) +
                  entries.length,
              itemBuilder: (context, index) {
                if (result.isLoading && index == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                int itemIndex = result.isLoading ? index - 1 : index;

                if (itemIndex < _pendingReceipts.length) {
                  final pending = _pendingReceipts[itemIndex];
                  final isReady = pending['isReady'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isReady ? cs.primary : cs.outlineVariant,
                        width: isReady ? 2 : 1,
                      ),
                    ),
                    elevation: 0,
                    color: isReady
                        ? cs.primaryContainer.withValues(alpha: 0.3)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: isReady
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        child: isReady
                            ? Icon(Icons.check, color: cs.onPrimary)
                            : const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                      title: Text(
                        pending['storeName'],
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontStyle: isReady
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.parse(pending['date'])),
                        style: textTheme.bodySmall,
                      ),
                      onTap: isReady
                          ? () {
                              context.go('/app/shopping/add');
                              setState(() {
                                _pendingReceipts.removeAt(index);
                              });
                            }
                          : null,
                    ),
                  );
                }

                int adjustedIndex = itemIndex - _pendingReceipts.length;

                if (stagingSession != null) {
                  if (adjustedIndex == 0) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.primary, width: 2),
                      ),
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: cs.primary,
                          child: Icon(Icons.check, color: cs.onPrimary),
                        ),
                        trailing:
                            (stagingSession['receiptImageUrl'] != null &&
                                stagingSession['receiptImageUrl']
                                    .toString()
                                    .isNotEmpty &&
                                stagingSession['receiptImageUrl']
                                    .toString()
                                    .startsWith('http'))
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: stagingSession['receiptImageUrl'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.receipt_long, size: 30),
                                ),
                              )
                            : null,
                        title: Text(
                          'receipt_ready_tap'.tr(),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${stagingSession['detectedStore'] ?? 'Unknown Store'} • ${DateFormat('yyyy-MM-dd').format(DateTime.parse(stagingSession['createdAt']))}',
                          style: textTheme.bodySmall,
                        ),
                        onTap: () => context.go('/app/shopping/add'),
                      ),
                    );
                  }
                  adjustedIndex--;
                }

                final entry = entries[adjustedIndex];
                final isImported = entry['isImported'] == true;
                final dateStr = entry['date'] as String;
                final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                final formattedDate = DateFormat('yyyy-MM-dd').format(date);

                return Mutation(
                  options: MutationOptions(
                    document: gql(_deleteMutation),
                    onCompleted: (data) {
                      refetch?.call();
                    },
                  ),
                  builder:
                      (RunMutation runMutation, QueryResult? deleteResult) {
                        return Dismissible(
                          key: Key(entry['id']),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('delete_history_confirm'.tr()),
                                  content: Text(
                                    'delete_item_confirm_message'.tr(),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text('cancel'.tr()),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        'delete'.tr(),
                                        style: TextStyle(color: cs.error),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            runMutation({'id': entry['id']});
                          },
                          background: Container(
                            color: cs.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              onTap: () {
                                context.go('/app/shopping/add', extra: entry);
                              },
                              leading: CircleAvatar(
                                backgroundColor: isImported
                                    ? cs.secondaryContainer
                                    : cs.primaryContainer,
                                child: Icon(
                                  isImported
                                      ? Icons.check_circle
                                      : Icons.shopping_cart,
                                  color: isImported
                                      ? cs.onSecondaryContainer
                                      : cs.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                entry['storeName'] ?? 'unknown_store'.tr(),
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: textTheme.bodySmall,
                                  ),
                                  Text(
                                    'items_count'.plural(
                                      entry['itemsSnapshot']?.length ?? 0,
                                    ),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: cs.outline,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (entry['receiptImageUrl'] != null &&
                                      entry['receiptImageUrl']
                                          .toString()
                                          .isNotEmpty &&
                                      entry['receiptImageUrl']
                                          .toString()
                                          .startsWith('http'))
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: entry['receiptImageUrl'],
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const SizedBox(
                                                width: 40,
                                                height: 40,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.receipt_long,
                                                size: 24,
                                              ),
                                        ),
                                      ),
                                    ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${entry['totalAmount']} ${'eur'.tr()}',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: cs.primary,
                                        ),
                                      ),
                                      if (isImported)
                                        Text(
                                          'history_imported'.tr(),
                                          style: textTheme.labelSmall?.copyWith(
                                            color: cs.onSecondaryContainer,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
