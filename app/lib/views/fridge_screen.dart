import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/inventory_service.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/models/recipe_model.dart';
import 'package:mocc/widgets/fridge_item_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/service/shared_fridge_service.dart';
import 'package:share_plus/share_plus.dart';

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

  String? selectedFridgeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMeId();
    _refreshRecipes();
  }

  void _refreshRecipes() {
    setState(() {
      _recipesFuture = recipeService.getMyRecipes(includeAi: false);
      inventoryItems = inventoryService.getMyFridges();
    });
  }

  Future<void> _loadMeId() async {
    final id = await userSvc.getUserId();
    setState(() {
      meId = id;
    });
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
                    final newItems = await inventoryService.getMyFridges();
                    if (!mounted) return;
                    setState(() {
                      inventoryItems = Future.value(newItems);
                    });
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
    ref.listen(fridgeRefreshProvider, (previous, next) {
      _refreshRecipes();
    });

    return FutureBuilder<List<Fridge>>(
      future: inventoryItems,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (asyncSnapshot.hasError) {
          return Center(
            child: Text(
              tr('error_occurred', args: [asyncSnapshot.error.toString()]),
            ),
          );
        }

        final fridges = asyncSnapshot.data ?? [];

        if (fridges.isEmpty) {
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
                            onPressed: () {
                              controller.isOpen
                                  ? controller.close()
                                  : controller.open();
                            },
                            child: Text(
                              '${tr("fridge")} ${fridges.indexOf(selectedFridge) + 1}${selectedFridge.id == meId ? " * " : ""} ▼',
                            ),
                          );
                        },
                        menuChildren: [
                          ...fridges.map((f) {
                            final isSelected = f.id == selectedFridgeId;
                            final fridgeIndex = fridges.indexOf(f) + 1;

                            return MenuItemButton(
                              onPressed: () {
                                setState(() {
                                  selectedFridgeId = f.id;
                                });
                              },
                              child: Text(
                                '${tr("fridge")} $fridgeIndex ${f.id == meId ? "*" : ""}',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                      ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 110),
                        itemCount: selectedFridge.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return FridgeItem(
                            item: selectedFridge.items[index],
                            onTap: () async {
                              final result = await context.push(
                                '/app/inventory/item?fridgeId=${selectedFridge.id}&id=${selectedFridge.items[index].id}',
                              );
                              if (result == true) {
                                setState(() {
                                  inventoryItems = inventoryService
                                      .getMyFridges();
                                });
                              }
                            },
                          );
                        },
                      ),
                      FutureBuilder<List<Recipe>>(
                        future: _recipesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                tr(
                                  'error_occurred',
                                  args: [snapshot.error.toString()],
                                ),
                              ),
                            );
                          }
                          final recipes = snapshot.data ?? [];
                          if (recipes.isEmpty) {
                            return Center(child: Text(tr("no_recipes_found")));
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
                                            _refreshRecipes();
                                          }
                                        },
                                ),
                              );
                            },
                          );
                        },
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
                        _refreshRecipes();
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
