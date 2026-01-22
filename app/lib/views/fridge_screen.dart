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
  late final RecipeService recipeService = RecipeService(userService);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Fridge>>(
      future: inventoryItems,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (asyncSnapshot.hasError) {
          return Center(child: Text('Error: ${asyncSnapshot.error}'));
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

        selectedFridgeId ??= fridges.first.id;

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
                        padding: const EdgeInsets.all(8),
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
                              child: Text("Error: ${snapshot.error}"),
                            );
                          }
                          final recipes = snapshot.data ?? [];
                          if (recipes.isEmpty) {
                            return Center(child: Text(tr("no_recipes_found")));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: recipes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final recipe = recipes[index];
                              return Card(
                                child: ListTile(
                                  title: Text(recipe.title),
                                  subtitle: Text(
                                    recipe.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    tr(
                                      'recipe_status.${recipe.status.name.toLowerCase()}',
                                    ),
                                  ),
                                  onTap: () async {
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
