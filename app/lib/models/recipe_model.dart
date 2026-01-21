import 'enums.dart';
import 'inventory_model.dart';

class Recipe {
  final String id;
  final String authorId;
  final String title;
  final String description;
  final RecipeStatus status;
  final List<RecipeIngredient>? ingredients;
  final List<RecipeCookedItem>? cookedItems;
  final List<String>? steps;
  final int? prepTimeMinutes;
  final int? calories;
  final int? ecoPointsReward;
  final int? ttlSecondsRemaining;
  final bool generatedByAI;

  Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    required this.status,
    this.ingredients,
    this.cookedItems,
    this.steps,
    this.prepTimeMinutes,
    this.calories,
    this.ecoPointsReward,
    this.ttlSecondsRemaining,
    required this.generatedByAI,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: RecipeStatus.fromJson(json['status'] as String),
      ingredients: (json['ingredients'] as List<dynamic>?)
          ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      cookedItems: (json['cookedItems'] as List<dynamic>?)
          ?.map((e) => RecipeCookedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>?)?.cast<String>(),
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      calories: json['calories'] as int?,
      ecoPointsReward: json['ecoPointsReward'] as int?,
      ttlSecondsRemaining: json['ttlSecondsRemaining'] as int?,
      generatedByAI: json['generatedByAI'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'title': title,
    'description': description,
    'status': status.toJson(),
    'ingredients': ingredients?.map((e) => e.toJson()).toList(),
    'cookedItems': cookedItems?.map((e) => e.toJson()).toList(),
    'steps': steps,
    'prepTimeMinutes': prepTimeMinutes,
    'calories': calories,
    'ecoPointsReward': ecoPointsReward,
    'ttlSecondsRemaining': ttlSecondsRemaining,
    'generatedByAI': generatedByAI,
  };
}

class RecipeCookedItem {
  final String id;
  final String name;
  final String? brand;
  final String? category;
  final Quantity quantity;
  final double? price;
  final double usedQuantity;
  final String? originalInventoryId;

  RecipeCookedItem({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    required this.quantity,
    this.price,
    required this.usedQuantity,
    this.originalInventoryId,
  });

  factory RecipeCookedItem.fromJson(Map<String, dynamic> json) {
    return RecipeCookedItem(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      quantity: Quantity.fromJson(json['quantity'] as Map<String, dynamic>),
      price: (json['price'] as num?)?.toDouble(),
      usedQuantity: (json['usedQuantity'] as num).toDouble(),
      originalInventoryId: json['originalInventoryId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'quantity': quantity.toJson(),
    'price': price,
    'usedQuantity': usedQuantity,
    'originalInventoryId': originalInventoryId,
  };
}

class RecipeIngredient {
  final String name;
  final double quantity;
  final Unit unit;
  final bool isAvailableInFridge;
  final String? inventoryItemId;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isAvailableInFridge,
    this.inventoryItemId,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: Unit.fromJson(json['unit'] as String),
      isAvailableInFridge: json['isAvailableInFridge'] as bool,
      inventoryItemId: json['inventoryItemId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit.toJson(),
    'isAvailableInFridge': isAvailableInFridge,
    if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
  };
}

class RecipeIngredientInput {
  final String name;
  final double quantity;
  final Unit unit;
  final String? inventoryItemId;

  RecipeIngredientInput({
    required this.name,
    required this.quantity,
    required this.unit,
    this.inventoryItemId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit.toJson(),
    if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
  };
}

class CreateRecipeInput {
  final String title;
  final String? description;
  final List<RecipeIngredientInput> ingredients;
  final List<String> steps;
  final int? prepTimeMinutes;
  final int? calories;
  final int? ecoPointsReward;

  CreateRecipeInput({
    required this.title,
    this.description,
    required this.ingredients,
    required this.steps,
    this.prepTimeMinutes,
    this.calories,
    this.ecoPointsReward,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'steps': steps,
    'prepTimeMinutes': prepTimeMinutes,
    'calories': calories,
    'ecoPointsReward': ecoPointsReward,
  };
}

class UpdateRecipeInput {
  final String? title;
  final String? description;
  final RecipeStatus? status;
  final List<RecipeIngredientInput>? ingredients;
  final List<String>? steps;
  final int? prepTimeMinutes;
  final int? calories;

  UpdateRecipeInput({
    this.title,
    this.description,
    this.status,
    this.ingredients,
    this.steps,
    this.prepTimeMinutes,
    this.calories,
  });

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (status != null) 'status': status!.toJson(),
    if (ingredients != null)
      'ingredients': ingredients!.map((e) => e.toJson()).toList(),
    if (steps != null) 'steps': steps,
    if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
    if (calories != null) 'calories': calories,
  };
}
