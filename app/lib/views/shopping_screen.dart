import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/service/shopping_service.dart';

enum SortOption { dateDesc, dateAsc, priceDesc, priceAsc }

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  SortOption _currentSort = SortOption.dateDesc;

  static const int _pageSize = 50;

  final String _query = ShoppingService.getShoppingHistoryQuery;
  final String _deleteMutation = ShoppingService.deleteShoppingHistoryMutation;

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
          onPressed: () {
            context.go('/app/shopping/add');
          },
          label: Text('new_shopping_trip'.tr()),
          icon: const Icon(Icons.add),
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
        builder:
            (
              QueryResult result, {
              VoidCallback? refetch,
              FetchMore? fetchMore,
            }) {
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

              if (entries.isEmpty) {
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
                    final priceA =
                        (a['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final priceB =
                        (b['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    return priceB.compareTo(priceA);
                  case SortOption.priceAsc:
                    final priceA =
                        (a['totalAmount'] as num?)?.toDouble() ?? 0.0;
                    final priceB =
                        (b['totalAmount'] as num?)?.toDouble() ?? 0.0;
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
                          variables: {
                            'offset': entries.length,
                            'limit': _pageSize,
                          },
                          updateQuery:
                              (previousResultData, fetchMoreResultData) {
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
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + (result.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final entry = entries[index];
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
                                      title: Text(
                                        'delete_history_confirm'.tr(),
                                      ),
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
                                    context.go(
                                      '/app/shopping/add',
                                      extra: entry,
                                    );
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  trailing: Column(
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
