import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/inventory_model.dart';
import '../models/shopping_model.dart';

class ShoppingRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final shoppingRefreshProvider = NotifierProvider<ShoppingRefreshNotifier, int>(
  ShoppingRefreshNotifier.new,
);

class ShoppingService {
  final GraphQLClient client;

  ShoppingService(this.client);

  static const String getShoppingHistoryQuery = r'''
    query GetShoppingHistory($limit: Int, $offset: Int) {
      shoppingHistory(limit: $limit, offset: $offset) {
        id
        authorId
        date
        storeName
        totalAmount
        currency
        isImported
        itemsSnapshot {
          name
          price
          quantity
          unit
          category
          brand
          expiryDate
          expiryType
        }
      }
    }
  ''';

  static const String deleteShoppingHistoryMutation = r'''
    mutation DeleteShoppingHistory($id: ID!) {
      deleteShoppingHistory(id: $id)
    }
  ''';

  static const String addShoppingHistoryMutation = r'''
    mutation AddShoppingHistory($input: AddShoppingHistoryInput!) {
      addShoppingHistory(input: $input) {
        id
      }
    }
  ''';

  static const String updateShoppingHistoryMutation = r'''
    mutation UpdateShoppingHistory($id: ID!, $input: UpdateShoppingHistoryInput!) {
      updateShoppingHistory(id: $id, input: $input) {
        id
      }
    }
  ''';

  static const String importShoppingHistoryToFridgeMutation = r'''
    mutation ImportShoppingHistoryToFridge($id: ID!) {
      importShoppingHistoryToFridge(id: $id) {
        id
        isImported
      }
    }
  ''';

  static const String getSuggestionsQuery = r'''
    query GetSuggestions {
      shoppingHistory(limit: 50) {
        storeName
        itemsSnapshot {
          name
          category
          brand
        }
      }
      myFridge {
        items {
          name
          category
          brand
        }
      }
    }
  ''';

  Future<StagingSession?> getCurrentStagingSession() async {
    const String query = r'''
      query CurrentStagingSession {
        currentStagingSession {
          id
          detectedStore
          detectedTotal
          createdAt
          expiresAt
          items {
            id
            name
            detectedPrice
            quantity
            confidence
          }
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final data = result.data?['currentStagingSession'];
    if (data == null) {
      return null;
    }

    return StagingSession.fromJson(data);
  }

  Future<List<ShoppingHistoryEntry>> getShoppingHistory({
    int limit = 10,
    int offset = 0,
  }) async {
    const String query = getShoppingHistoryQuery;

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'limit': limit, 'offset': offset},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> historyJson =
        result.data?['shoppingHistory'] as List<dynamic>? ?? [];
    return historyJson
        .map((e) => ShoppingHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StagingSession> createStagingSession(String? receiptImageUrl) async {
    const String mutation = r'''
      mutation CreateStagingSession($receiptImageUrl: String) {
        createStagingSession(receiptImageUrl: $receiptImageUrl) {
          id
          detectedStore
          detectedTotal
          createdAt
          expiresAt
          items {
            id
            name
            detectedPrice
            quantity
            confidence
          }
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'receiptImageUrl': receiptImageUrl},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['createStagingSession'] == null) {
      throw Exception('Failed to create staging session');
    }

    return StagingSession.fromJson(result.data!['createStagingSession']);
  }

  Future<StagingItem> addItemToStaging(
    String sessionId,
    String name,
    int? quantity,
  ) async {
    const String mutation = r'''
      mutation AddItemToStaging($sessionId: ID!, $name: String!, $quantity: Int) {
        addItemToStaging(sessionId: $sessionId, name: $name, quantity: $quantity) {
            id
            name
            detectedPrice
            quantity
            confidence
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'sessionId': sessionId, 'name': name, 'quantity': quantity},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['addItemToStaging'] == null) {
      throw Exception('Failed to add item to staging');
    }

    return StagingItem.fromJson(result.data!['addItemToStaging']);
  }

  Future<StagingItem> updateStagingItem(
    String sessionId,
    String itemId,
    StagingItemInput input,
  ) async {
    const String mutation = r'''
      mutation UpdateStagingItem($sessionId: ID!, $itemId: ID!, $input: StagingItemInput!) {
        updateStagingItem(sessionId: $sessionId, itemId: $itemId, input: $input) {
            id
            name
            detectedPrice
            quantity
            confidence
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {
        'sessionId': sessionId,
        'itemId': itemId,
        'input': input.toJson(),
      },
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['updateStagingItem'] == null) {
      throw Exception('Failed to update staging item');
    }

    return StagingItem.fromJson(result.data!['updateStagingItem']);
  }

  Future<bool> deleteStagingItem(String sessionId, String itemId) async {
    const String mutation = r'''
      mutation DeleteStagingItem($sessionId: ID!, $itemId: ID!) {
        deleteStagingItem(sessionId: $sessionId, itemId: $itemId)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'sessionId': sessionId, 'itemId': itemId},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['deleteStagingItem'] as bool? ?? false;
  }

  Future<List<InventoryItem>> commitStagingSession(String sessionId) async {
    const String mutation = r'''
      mutation CommitStagingSession($sessionId: ID!) {
        commitStagingSession(sessionId: $sessionId) {
          id
          name
          brand
          category
          quantity {
            value
            unit
          }
          virtualAvailable
          expiryDate
          expiryType
          addedAt
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'sessionId': sessionId},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> itemsJson =
        result.data?['commitStagingSession'] as List<dynamic>? ?? [];
    return itemsJson
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> discardStagingSession(String sessionId) async {
    const String mutation = r'''
      mutation DiscardStagingSession($sessionId: ID!) {
        discardStagingSession(sessionId: $sessionId)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'sessionId': sessionId},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['discardStagingSession'] as bool? ?? false;
  }
}
