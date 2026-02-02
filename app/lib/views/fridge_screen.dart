import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/inventory_service.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/models/recipe_model.dart';
import 'package:mocc/service/server_health_service.dart';
import 'package:mocc/widgets/fridge_item_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/service/shared_fridge_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mocc/widgets/unified_error_widget.dart';
import 'package:mocc/service/signal_service.dart';

class FridgeScreen extends ConsumerStatefulWidget {
  const FridgeScreen({super.key});

  @override
  ConsumerState<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends ConsumerState<FridgeScreen>
    with SingleTickerProviderStateMixin {
  late final userService = ref.read(graphQLClientProvider);
  late final UserService userSvc = UserService(userService);
  late final InventoryService inventoryService = InventoryService(userService);
  late final SharedFridgeService sharedFridgeService = SharedFridgeService(
    userService,
  );
  late final RecipeService recipeService = ref.read(recipeServiceProvider);
  late Future<List<Fridge>> inventoryItems = inventoryService.getMyFridges();
  late Future<List<Recipe>> _recipesFuture;
  late final TabController _tabController;

  late String meId = '';

  List<Fridge>? _lastFridges;
  List<Recipe>? _lastRecipes;
  String? selectedFridgeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMeId();
    _refreshAll();
  }

  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final fridgesFuture = inventoryService.getMyFridges();
    final recipesFuture = recipeService.getMyRecipes(includeAi: true);

    setState(() {
      inventoryItems = fridgesFuture;
      _recipesFuture = recipesFuture;
    });

    try {
      final results = await Future.wait([fridgesFuture, recipesFuture]);
      final recipes = results[1] as List<Recipe>;

      // Check if we need to poll (if pending recipes exist)
      final hasPending = recipes.any((r) => r.id.startsWith('pending-'));
      if (hasPending) {
        if (_pollingTimer == null || !_pollingTimer!.isActive) {
          _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
            _refreshAll();
          });
        }
      } else {
        _pollingTimer?.cancel();
        _pollingTimer = null;
      }
    } catch (e) {
      debugPrint("Error refreshing data: $e");
    }
  }

  Future<void> _loadMeId() async {
    try {
      final id = await userSvc.getUserId();
      if (mounted) {
        setState(() {
          meId = id;
        });
      }
    } catch (e) {
      debugPrint('Error loading user ID: $e');
    }
  }

  Future<void> _shareFridge(String fridgeId) async {
    try {
      final link = await sharedFridgeService.generateSharedFridgeLink();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('share_invite_code')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                link.inviteCode,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'invite_expires_msg'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('share_code_message', args: [link.inviteCode]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            FilledButton.icon(
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: tr('share_code_message', args: [link.inviteCode]),
                  ),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share),
              label: Text(tr('share_fridge')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_occurred', args: [e.toString()]))),
      );
    }
  }

  Future<void> _addSharedFridge() async {
    final TextEditingController codeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('join_fridge')),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText: tr('code'),
            hintText: tr('enter_share_code'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                try {
                  final id = await sharedFridgeService.addFridgeShared(code);
                  if (!mounted) return;

                  if (id != null) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _refreshAll();
                    messenger.showSnackBar(
                      SnackBar(content: Text(tr('fridge_added'))),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(tr('invalid_code'))),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  final message =
                      e.toString().contains('cannot share fridge with yourself')
                      ? tr('cannot_share_with_yourself')
                      : tr('error_occurred', args: [e.toString()]);
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                }
              }
            },
            child: Text(tr('add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServerStatus>(serverHealthProvider, (previous, next) {
      if (next == ServerStatus.online && previous != ServerStatus.online) {
        debugPrint('[Fridge] Server is now online, auto-refreshing...');
        _refreshAll();
      }
    });

    ref.listen(signalRefreshProvider, (_, _) {
      debugPrint('[Fridge] SignalR refresh received');
      _refreshAll();
    });

    ref.listen(fridgeRefreshProvider, (previous, next) {
      _refreshAll();
    });

    return FutureBuilder<List<Fridge>>(
      future: inventoryItems,
      initialData: _lastFridges,
      builder: (context, asyncSnapshot) {
        // Update cache if we have new data
        if (asyncSnapshot.hasData) {
          _lastFridges = asyncSnapshot.data;
        }

        // Show loading ONLY if we have no data at all (first load)
        if (asyncSnapshot.connectionState == ConnectionState.waiting &&
            _lastFridges == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (asyncSnapshot.hasError && _lastFridges == null) {
          // Only show error if we have no data to show
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: UnifiedErrorWidget(
                error: asyncSnapshot.error,
                onRetry: _refreshAll,
              ),
            ),
          );
        }

        final fridges = _lastFridges ?? [];

        if (fridges.isEmpty) {
          // Check if it's truly empty or just failed
          if (asyncSnapshot.hasError) {
            return Center(
              child: UnifiedErrorWidget(
                error: asyncSnapshot.error,
                onRetry: _refreshAll,
              ),
            );
          }
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(
                  tr("no_fridge_found"),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        if (selectedFridgeId == null) {
          try {
            selectedFridgeId = fridges.firstWhere((f) => f.id == meId).id;
          } catch (_) {
            selectedFridgeId = fridges.first.id;
          }
        }

        final selectedFridge = fridges.firstWhere(
          (f) => f.id == selectedFridgeId,
          orElse: () => fridges.first,
        );

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      MenuAnchor(
                        builder: (context, controller, child) {
                          return FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selectedFridge.id == meId
                                      ? Icons.kitchen
                                      : Icons.kitchen_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tr("fridge")} ${fridges.indexOf(selectedFridge) + 1}${selectedFridge.id == meId ? " (Me)" : ""}',
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          );
                        },
                        menuChildren: [
                          ...fridges.map((f) {
                            final isSelected = f.id == selectedFridgeId;
                            final fridgeIndex = fridges.indexOf(f) + 1;
                            final isMe = f.id == meId;

                            return MenuItemButton(
                              leadingIcon: Icon(
                                isMe ? Icons.kitchen : Icons.kitchen_outlined,
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer
                                    : null,
                              ),
                              style: ButtonStyle(
                                backgroundColor: isSelected
                                    ? MaterialStatePropertyAll(
                                        Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer,
                                      )
                                    : null,
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedFridgeId = f.id;
                                });
                              },
                              child: Text(
                                '${tr("fridge")} $fridgeIndex${isMe ? " (Me)" : ""}',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _addSharedFridge,
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        onPressed: () => _shareFridge(selectedFridgeId!),
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: tr("items")),
                    Tab(text: tr("recipes")),
                  ],
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _refreshAll,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 110),
                          itemCount: selectedFridge.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return FridgeItem(
                              item: selectedFridge.items[index],
                              onTap: () async {
                                final result = await context.push(
                                  '/app/inventory/item?fridgeId=${selectedFridge.id}&id=${selectedFridge.items[index].id}',
                                );
                                if (result == true) {
                                  _refreshAll();
                                }
                              },
                            );
                          },
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _refreshAll,
                        child: FutureBuilder<List<Recipe>>(
                          future: _recipesFuture,
                          initialData: _lastRecipes,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              _lastRecipes = snapshot.data;
                            }

                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _lastRecipes == null) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError && _lastRecipes == null) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: UnifiedErrorWidget(
                                    error: snapshot.error,
                                    onRetry: _refreshAll,
                                  ),
                                ),
                              );
                            }

                            final recipes = _lastRecipes ?? [];
                            if (recipes.isEmpty) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: UnifiedErrorWidget(
                                    error: snapshot.error,
                                    onRetry: _refreshAll,
                                  ),
                                );
                              }
                              return Center(
                                child: Text(tr("no_recipes_found")),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 110),
                              itemCount: recipes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final recipe = recipes[index];
                                final isPending = recipe.id.startsWith(
                                  'pending-',
                                );
                                return Card(
                                  child: ListTile(
                                    title: Text(recipe.title),
                                    subtitle: Text(
                                      recipe.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: isPending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            tr(
                                              'recipe_status.${recipe.status.name.toLowerCase()}',
                                            ),
                                          ),
                                    onTap: isPending
                                        ? null
                                        : () async {
                                            final result = await context.push(
                                              '/app/recipe?id=${recipe.id}',
                                              extra: selectedFridge,
                                            );
                                            if (result == true) {
                                              _refreshAll();
                                            }
                                          },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: _tabController.index == 1
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 110),
                  child: FloatingActionButton(
                    shape: const CircleBorder(),
                    onPressed: () async {
                      final result = await context.push(
                        '/app/recipe',
                        extra: selectedFridge,
                      );
                      if (result == true) {
                        _refreshAll();
                      }
                    },
                    heroTag: 'add_manual_recipe',
                    child: const Icon(Icons.add),
                  ),
                )
              : null,
        );
      },
    );
  }
}
