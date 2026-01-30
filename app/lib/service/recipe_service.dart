import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/recipe_model.dart';
import '../models/enums.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/service/graphql_config.dart';

final recipeServiceProvider = Provider<RecipeService>((ref) {
  final client = ref.watch(graphQLClientProvider);
  return RecipeService(client);
});

class RecipeService {
  final GraphQLClient client;

  RecipeService(this.client);

  final List<Recipe> _pendingRecipes = [];
  int _lastAiCount = 0;

  void addPendingRecipe(Recipe recipe) {
    _pendingRecipes.add(recipe);
    // Timer to auto-remove if backend fails
    Future.delayed(const Duration(minutes: 5), () {
      _pendingRecipes.removeWhere((r) => r.id == recipe.id);
    });
  }

  Future<List<Recipe>> getMyRecipes({
    RecipeStatus? status,
    bool includeAi = false,
  }) async {
    const String query = r'''
      query MyRecipes($status: RecipeStatus) {
        myRecipes(status: $status) {
          id
          authorId
          title
          description
          status
          ingredients {
            name
            quantity
            unit
            inventoryItemId
            isAvailableInFridge
          }
          steps
          prepTimeMinutes
          calories
          ecoPointsReward
          ttlSecondsRemaining
          generatedByAI
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'status': status?.toJson()},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> recipesJson =
        result.data?['myRecipes'] as List<dynamic>? ?? [];

    final allRecipes = recipesJson
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();

    // Check for new AI recipes to clear pending
    final currentAiCount = allRecipes.where((r) => r.generatedByAI).length;
    if (_pendingRecipes.isNotEmpty && currentAiCount > _lastAiCount) {
      // A new AI recipe appeared, remove pending ones
      _pendingRecipes.clear();
    }
    _lastAiCount = currentAiCount;

    final fetchedRecipes = allRecipes
        .where((r) => includeAi || !r.generatedByAI)
        .toList();

    return [..._pendingRecipes, ...fetchedRecipes];
  }

  Future<List<Recipe>> getMyAiRecipes({RecipeStatus? status}) async {
    const String query = r'''
      query MyRecipes($status: RecipeStatus) {
        myRecipes(status: $status) {
          id
          authorId
          title
          description
          status
          ingredients {
            name
            quantity
            unit
            inventoryItemId
            isAvailableInFridge
          }
          steps
          prepTimeMinutes
          calories
          ecoPointsReward
          ttlSecondsRemaining
          generatedByAI
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'status': status?.toJson()},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> recipesJson =
        result.data?['myRecipes'] as List<dynamic>? ?? [];
    return recipesJson
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .where((recipe) => recipe.generatedByAI)
        .toList();
  }

  Future<Recipe?> getRecipe(String id) async {
    const String query = r'''
      query Recipe($id: ID!) {
        recipe(id: $id) {
          id
          authorId
          title
          description
          status
          ingredients {
            name
            quantity
            unit
            inventoryItemId
            isAvailableInFridge
          }
          cookedItems {
            id
            name
            usedQuantity
            quantity {
              value
              unit
            }
          }
          steps
          prepTimeMinutes
          calories
          ecoPointsReward
          ttlSecondsRemaining
          generatedByAI
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final data = result.data?['recipe'];
    if (data == null) {
      return null;
    }

    return Recipe.fromJson(data);
  }

  Future<Recipe> createRecipe(CreateRecipeInput input) async {
    const String mutation = r'''
      mutation CreateRecipe($input: CreateRecipeInput!) {
        createRecipe(input: $input) {
          id
          authorId
          title
          description
          status
          ingredients {
            name
            quantity
            unit
            inventoryItemId
            isAvailableInFridge
          }
          cookedItems {
            id
            name
            usedQuantity
            quantity {
              value
              unit
            }
          }
          steps
          prepTimeMinutes
          calories
          ecoPointsReward
          ttlSecondsRemaining
          generatedByAI
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'input': input.toJson()},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['createRecipe'] == null) {
      throw Exception('Failed to create recipe');
    }

    return Recipe.fromJson(result.data!['createRecipe']);
  }

  Future<Recipe> updateRecipe(String id, UpdateRecipeInput input) async {
    const String mutation = r'''
      mutation UpdateRecipe($id: ID!, $input: UpdateRecipeInput!) {
        updateRecipe(id: $id, input: $input) {
          id
          authorId
          title
          description
          status
          ingredients {
            name
            quantity
            unit
            inventoryItemId
            isAvailableInFridge
          }
          cookedItems {
            id
            name
            usedQuantity
            quantity {
              value
              unit
            }
          }
          steps
          prepTimeMinutes
          calories
          ecoPointsReward
          ttlSecondsRemaining
          generatedByAI
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'input': input.toJson()},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['updateRecipe'] == null) {
      throw Exception('Failed to update recipe');
    }

    return Recipe.fromJson(result.data!['updateRecipe']);
  }

  Future<bool> deleteRecipe(String id) async {
    const String mutation = r'''
      mutation DeleteRecipe($id: ID!) {
        deleteRecipe(id: $id)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['deleteRecipe'] as bool? ?? false;
  }

  Future<Recipe> saveRecipe(String id) async {
    const String mutation = r'''
      mutation SaveRecipe($id: ID!) {
        saveRecipe(id: $id) {
          id
          title
          status
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['saveRecipe'] == null) {
      throw Exception('Failed to save recipe');
    }

    return Recipe.fromJson(result.data!['saveRecipe']);
  }

  Future<Recipe> cookRecipe(String id) async {
    const String mutation = r'''
      mutation CookRecipe($id: ID!) {
        cookRecipe(id: $id) {
          id
          title
          status
          cookedItems {
            id
            name
            usedQuantity
            quantity {
              value
              unit
            }
          }
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['cookRecipe'] == null) {
      throw Exception('Failed to cook recipe');
    }

    return Recipe.fromJson(result.data!['cookRecipe']);
  }
}
