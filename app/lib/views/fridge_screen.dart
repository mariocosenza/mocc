import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/inventory_service.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/widgets/fridge_item_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FridgeScreen extends ConsumerStatefulWidget {
  const FridgeScreen({super.key});

  @override
  ConsumerState<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends ConsumerState<FridgeScreen> {
  late final userService = ref.read(graphQLClientProvider);
  late final UserService userSvc = UserService(userService);
  late final InventoryService inventoryService = InventoryService(userService);
  late final Future<List<Fridge>> inventoryItems = inventoryService
      .getMyFridges();
  late String meId = '';

  String? selectedFridgeId;

  @override
  void initState() {
    super.initState();
    _loadMeId();
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

        // Initialize selection once (first fridge) if not set yet.
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

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: selectedFridge.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return FridgeItem(
                        item: selectedFridge.items[index],
                        onTap: () {
                          context.push(
                            '/app/inventory/item?fridgeId=${selectedFridge.id}&id=${selectedFridge.items[index].id}',
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
