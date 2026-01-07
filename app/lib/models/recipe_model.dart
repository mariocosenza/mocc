import 'enums.dart';

class Recipe {
  final String id;
  final String authorId;
  final String title;
  final String? description;
  final RecipeStatus status;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final int? prepTimeMinutes;
  final int? calories;
  final int? ecoPointsReward;
  final int? ttlSecondsRemaining;
  final bool generatedByAI;

  Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    required this.status,
    required this.ingredients,
    required this.steps,
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
      description: json['description'] as String?,
      status: RecipeStatus.fromJson(json['status'] as String),
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>).cast<String>(),
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      calories: json['calories'] as int?,
      ecoPointsReward: json['ecoPointsReward'] as int?,
      ttlSecondsRemaining: json['ttlSecondsRemaining'] as int?,
      generatedByAI: json['generatedByAI'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'title': title,
        'description': description,
        'status': status.toJson(),
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
        'prepTimeMinutes': prepTimeMinutes,
        'calories': calories,
        'ecoPointsReward': ecoPointsReward,
        'ttlSecondsRemaining': ttlSecondsRemaining,
        'generatedByAI': generatedByAI,
      };
}

class RecipeIngredient {
  final String name;
  final double quantity;
  final Unit unit;
  final bool isAvailableInFridge;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isAvailableInFridge,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: Unit.fromJson(json['unit'] as String),
      isAvailableInFridge: json['isAvailableInFridge'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit.toJson(),
        'isAvailableInFridge': isAvailableInFridge,
      };
}

