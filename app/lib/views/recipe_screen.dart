import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/enums.dart';
import 'package:mocc/models/inventory_model.dart';
import 'package:mocc/models/recipe_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mocc/service/common_service.dart';
import 'dart:developer' as developer;

class RecipeScreen extends ConsumerStatefulWidget {
  final Fridge fridge;
  final String? recipeId;

  const RecipeScreen({super.key, required this.fridge, this.recipeId});

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late RecipeService _recipeService;

  bool _isLoading = false;
  Recipe? _recipe;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _caloriesController = TextEditingController();

  List<RecipeIngredientInput> _ingredients = [];
  List<String> _steps = [];
  RecipeStatus _status = RecipeStatus.proposed;

  int get _ecoPoints {
    int points = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final ing in _ingredients) {
      if (ing.inventoryItemId != null) {
        try {
          final item = widget.fridge.items.firstWhere(
            (i) => i.id == ing.inventoryItemId,
          );
          final exp = DateTime(
            item.expiryDate.year,
            item.expiryDate.month,
            item.expiryDate.day,
          );
          final daysUntil = exp.difference(today).inDays;

          if (exp.isBefore(today)) continue;

          if (daysUntil < 3) {
            points += 50;
          } else if (daysUntil < 7) {
            points += 20;
          } else if (daysUntil < 14) {
            points += 10;
          } else {
            points += 1;
          }
        } catch (_) {}
      }
    }
    return points;
  }

  @override
  void initState() {
    super.initState();
    _recipeService = ref.read(recipeServiceProvider);
    if (widget.recipeId != null) {
      _loadRecipe();
    }
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    try {
      final recipe = await _recipeService.getRecipe(widget.recipeId!);
      if (recipe != null) {
        _recipe = recipe;
        _titleController.text = recipe.title;
        _descriptionController.text = recipe.description;
        _prepTimeController.text = recipe.prepTimeMinutes?.toString() ?? '';
        _caloriesController.text = recipe.calories?.toString() ?? '';
        _ingredients =
            recipe.ingredients
                ?.map(
                  (e) => RecipeIngredientInput(
                    name: e.name,
                    quantity: e.quantity,
                    unit: e.unit,
                    inventoryItemId: e.inventoryItemId,
                  ),
                )
                .toList() ??
            [];
        _steps = List.from(recipe.steps ?? []);
        _status = recipe.status;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_loading_recipe', args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateQuantities()) return;
    setState(() => _isLoading = true);

    try {
      final calories = int.tryParse(_caloriesController.text);
      if (widget.recipeId == null) {
        final input = CreateRecipeInput(
          title: _titleController.text,
          description: _descriptionController.text,
          ingredients: _ingredients,
          steps: _steps,
          prepTimeMinutes: int.tryParse(_prepTimeController.text),
          calories: calories,
          ecoPointsReward: _ecoPoints,
        );
        await _recipeService.createRecipe(input);
      } else {
        final input = UpdateRecipeInput(
          title: _titleController.text,
          description: _descriptionController.text,
          ingredients: _ingredients,
          steps: _steps,
          status: _status,
          prepTimeMinutes: int.tryParse(_prepTimeController.text),
          calories: calories,
        );
        await _recipeService.updateRecipe(widget.recipeId!, input);
      }
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_saving_recipe', args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateQuantities() {
    final usage = <String, double>{};
    for (final ing in _ingredients) {
      if (ing.inventoryItemId != null) {
        usage[ing.inventoryItemId!] =
            (usage[ing.inventoryItemId!] ?? 0) + ing.quantity;
      }
    }

    for (final entry in usage.entries) {
      final itemId = entry.key;
      final totalNeeded = entry.value;

      final item = widget.fridge.items.firstWhere(
        (i) => i.id == itemId,
        orElse: () => InventoryItem(
          id: '',
          name: 'unknown'.tr(),
          quantity: Quantity(value: 0, unit: Unit.pz),
          status: ItemStatus.available,
          virtualAvailable: 0,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
          expiryType: ExpiryType.expiration,
          addedAt: DateTime.now(),
        ),
      );
      if (item.id.isNotEmpty) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final exp = DateTime(
          item.expiryDate.year,
          item.expiryDate.month,
          item.expiryDate.day,
        );

        if (exp.isBefore(today)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('cannot_use_expired_item', namedArgs: {'item': item.name}),
              ),
            ),
          );
          return false;
        }

        double available = item.virtualAvailable;
        if (widget.recipeId != null && item.activeLocks != null) {
          for (final lock in item.activeLocks!) {
            if (lock.recipeId == widget.recipeId) {
              available += lock.amount;
            }
          }
        }

        if (totalNeeded > available + 0.001) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'insufficient_quantity',
                  namedArgs: {
                    'item': item.name,
                    'available': available.toStringAsFixed(2),
                    'needed': totalNeeded.toStringAsFixed(2),
                  },
                ),
              ),
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _deleteRecipe() async {
    if (widget.recipeId == null) return;
    setState(() => _isLoading = true);
    try {
      await _recipeService.deleteRecipe(widget.recipeId!);
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_deleting_recipe', args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateFromImage() async {
    final picker = ImagePicker();
    bool dialogOpen = false;

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      if (mounted) {
        dialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(tr("uploading_image")),
              ],
            ),
          ),
        ).then((_) {
          if (dialogOpen) dialogOpen = false;
        });
      }

      final client = ref.read(graphQLClientProvider);
      final commonSvc = CommonService(client);
      final filename = pickedFile.name;
      final sasUrl = await commonSvc.generateUploadSasToken(
        filename,
        purpose: 'RECIPE_GENERATION',
      );

      final bytes = await pickedFile.readAsBytes();
      final response = await http.put(
        Uri.parse(sasUrl),
        headers: {'x-ms-blob-type': 'BlockBlob', 'Content-Type': 'image/jpeg'},
        body: bytes,
      );

      if (mounted && dialogOpen) {
        Navigator.of(context).pop();
        dialogOpen = false;
      }

      if (response.statusCode != 201) {
        throw Exception(
          tr('error_occurred', args: [response.statusCode.toString()]),
        );
      }

      final pendingRecipe = Recipe(
        id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
        authorId: '',
        title: tr('recipe_generation_started'),
        description: tr('recipe_generation_in_progress_message'),
        status: RecipeStatus.proposed,
        ingredients: [],
        steps: [],
        generatedByAI: true,
        prepTimeMinutes: 0,
        calories: 0,
      );
      _recipeService.addPendingRecipe(pendingRecipe);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.auto_awesome,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(tr("recipe_generation_started")),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr("recipe_generation_in_progress_message"),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  tr("recipe_generation_time_hint"),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop(true);
                },
                child: Text(tr("ok_will_check_later")),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && dialogOpen) {
        Navigator.of(context).pop();
        dialogOpen = false;
      }

      if (mounted) {
        developer.log('Generate Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_occurred', args: [e.toString()]))),
        );
      }
    }
  }

  Future<void> _addIngredient() async {
    await showDialog(
      context: context,
      builder: (context) => _AddIngredientDialog(
        fridgeItems: widget.fridge.items,
        onAdd: (ingredient) {
          setState(() {
            _ingredients.add(ingredient);
          });
        },
      ),
    );
  }

  void _addStep() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr("add_step")),
          content: TextField(controller: controller, maxLines: 3),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(tr("cancel")),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _steps.add(controller.text);
                  });
                  context.pop();
                }
              },
              child: Text(tr("add")),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipeId == null ? tr('new_recipe') : tr('edit_recipe'),
        ),
        actions: [
          if (widget.recipeId != null && _recipe?.generatedByAI != true)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteRecipe,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.recipeId == null) ...[
                FilledButton.icon(
                  onPressed: _generateFromImage,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(tr("generate_from_image")),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: tr('title')),
                validator: (v) =>
                    v == null || v.isEmpty ? tr('required') : null,
                readOnly:
                    _recipe?.generatedByAI == true ||
                    _status == RecipeStatus.cooked,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: tr('description')),
                maxLines: 3,
                readOnly:
                    _recipe?.generatedByAI == true ||
                    _status == RecipeStatus.cooked,
              ),
              const SizedBox(height: 20),
              if (widget.recipeId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tr('status')}: ${tr('recipe_status.${_status.name.toLowerCase()}')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
              ],
              Text(
                tr('ingredients'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._ingredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ing = entry.value;
                return ListTile(
                  title: Text(ing.name),
                  subtitle: Text(
                    '${ing.quantity} ${tr('unit_enum.${ing.unit.name.toLowerCase()}')}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        setState(() => _ingredients.removeAt(index)),
                  ),
                );
              }),
              if (_recipe?.generatedByAI != true)
                OutlinedButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add),
                  label: Text(tr('add_ingredient')),
                ),
              const SizedBox(height: 20),
              Text(tr('steps'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(step),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _steps.removeAt(index)),
                  ),
                );
              }),
              if (_recipe?.generatedByAI != true)
                OutlinedButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: Text(tr('add_step')),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeController,
                      decoration: InputDecoration(
                        labelText: tr('prep_time_min'),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      readOnly:
                          _recipe?.generatedByAI == true ||
                          _status == RecipeStatus.cooked,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      decoration: InputDecoration(labelText: tr('calories')),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      readOnly:
                          _recipe?.generatedByAI == true ||
                          _status == RecipeStatus.cooked,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('${tr('eco_points_reward')}: $_ecoPoints'),
              const SizedBox(height: 30),
              if (_recipe?.generatedByAI != true &&
                  _status != RecipeStatus.cooked)
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: _saveRecipe,
                  child: Text(
                    widget.recipeId == null
                        ? tr('create_recipe')
                        : tr('update_recipe'),
                  ),
                ),
              const SizedBox(height: 10),
              if (widget.recipeId != null &&
                  _status != RecipeStatus.cooked &&
                  _recipe?.generatedByAI != true) ...[
                if (_status != RecipeStatus.inPreparation)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      setState(() => _status = RecipeStatus.inPreparation);
                      _saveRecipe();
                    },
                    child: Text(tr('start_cooking')),
                  ),
                if (_status == RecipeStatus.inPreparation)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      setState(() => _status = RecipeStatus.cooked);
                      _saveRecipe();
                    },
                    child: Text(tr('complete_cooking')),
                  ),
                if (_status == RecipeStatus.inPreparation)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _status = RecipeStatus.saved);
                      _saveRecipe();
                    },
                    child: Text(tr('stop_cooking_revert')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddIngredientDialog extends StatefulWidget {
  final List<InventoryItem> fridgeItems;
  final ValueChanged<RecipeIngredientInput> onAdd;

  const _AddIngredientDialog({required this.fridgeItems, required this.onAdd});

  @override
  State<_AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<_AddIngredientDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  Unit _unit = Unit.g;
  InventoryItem? _selectedItem;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('add_ingredient')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InventoryItem>(
              isExpanded: true,
              initialValue: _selectedItem,
              decoration: InputDecoration(
                labelText: tr('from_fridge_optional'),
              ),
              items: [
                DropdownMenuItem<InventoryItem>(
                  value: null,
                  child: Text(
                    tr('custom_item'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...widget.fridgeItems
                    .where((i) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final exp = DateTime(
                        i.expiryDate.year,
                        i.expiryDate.month,
                        i.expiryDate.day,
                      );
                      return !exp.isBefore(today);
                    })
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          '${item.name} (${item.virtualAvailable} ${tr('available')})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedItem = v;
                  if (v != null) {
                    _nameController.text = v.name;
                    _unit = v.quantity.unit;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: tr('name')),
              enabled: _selectedItem == null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(labelText: tr('quantity')),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<Unit>(
                    initialValue: _unit,
                    items: Unit.values
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.toString().split('.').last),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedItem == null
                        ? (v) => setState(() => _unit = v!)
                        : null,
                    decoration: InputDecoration(labelText: tr('unit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(tr('cancel'))),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _quantityController.text.isNotEmpty) {
              final qty = double.tryParse(_quantityController.text) ?? 0;
              widget.onAdd(
                RecipeIngredientInput(
                  name: _nameController.text,
                  quantity: qty,
                  unit: _unit,
                  inventoryItemId: _selectedItem?.id,
                ),
              );
              context.pop();
            }
          },
          child: Text(tr('add')),
        ),
      ],
    );
  }
}
