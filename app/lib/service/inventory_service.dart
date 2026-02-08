import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/inventory_model.dart';

class FridgeRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final fridgeRefreshProvider = NotifierProvider<FridgeRefreshNotifier, int>(
  FridgeRefreshNotifier.new,
);

class InventoryService {
  final GraphQLClient client;

  InventoryService(this.client);

  Future<List<Fridge>> getMyFridges() async {
    const String query = r'''
    query MyFridge {
      myFridge {
        id
        name
        ownerId
        items {
          id
          name
          brand
          category
          quantity {
            value
            unit
          }
          price
          status
          virtualAvailable
          expiryDate
          expiryType
          addedAt
          activeLocks {
            recipeId
            amount
            startedAt
          }
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

    final data = result.data;
    if (data == null || data['myFridge'] == null) {
      throw Exception('No fridges found');
    }

    final dynamic raw = data['myFridge'];
    if (raw is List) {
      return raw
          .where((e) => e != null)
          .map((e) => Fridge.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (raw is Map<String, dynamic>) {
      return [Fridge.fromJson(raw)];
    }

    throw Exception('Unexpected myFridge payload: ${raw.runtimeType}');
  }

  Future<InventoryItem> addInventoryItem(AddInventoryItemInput input) async {
    const String mutation = r'''
      mutation AddInventoryItem($input: AddInventoryItemInput!) {
        addInventoryItem(input: $input) {
          id
          name
          brand
          category
          quantity {
            value
            unit
          }
          price
          status
          virtualAvailable
          expiryDate
          expiryType
          addedAt
          activeLocks {
            recipeId
            amount
            startedAt
          }
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

    if (result.data == null || result.data!['addInventoryItem'] == null) {
      throw Exception('Failed to add inventory item');
    }

    return InventoryItem.fromJson(result.data!['addInventoryItem']);
  }

  Future<InventoryItem> updateInventoryItem(
    String id,
    UpdateInventoryItemInput input,
  ) async {
    const String mutation = r'''
      mutation UpdateInventoryItem($id: ID!, $input: UpdateInventoryItemInput!) {
        updateInventoryItem(id: $id, input: $input) {
          id
          name
          brand
          category
          quantity {
            value
            unit
          }
          price
          status
          virtualAvailable
          expiryDate
          expiryType
          addedAt
          activeLocks {
            recipeId
            amount
            startedAt
          }
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

    if (result.data == null || result.data!['updateInventoryItem'] == null) {
      throw Exception('Failed to update inventory item');
    }

    return InventoryItem.fromJson(result.data!['updateInventoryItem']);
  }

  Future<bool> deleteInventoryItem(String id) async {
    const String mutation = r'''
      mutation DeleteInventoryItem($id: ID!) {
        deleteInventoryItem(id: $id)
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

    return result.data?['deleteInventoryItem'] as bool? ?? false;
  }

  Future<InventoryItem> consumeInventoryItem(String id, double amount) async {
    const String mutation = r'''
      mutation ConsumeInventoryItem($id: ID!, $amount: Float!) {
        consumeInventoryItem(id: $id, amount: $amount) {
          id
          quantity {
            value
            unit
          }
           virtualAvailable
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'amount': amount},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['consumeInventoryItem'] == null) {
      throw Exception('Failed to consume inventory item');
    }


    return InventoryItem.fromJson(result.data!['consumeInventoryItem']);
  }

  Future<InventoryItem> wasteInventoryItem(
    String id,
    double amount,
    String? reason,
  ) async {
    const String mutation = r'''
      mutation WasteInventoryItem($id: ID!, $amount: Float!, $reason: String) {
        wasteInventoryItem(id: $id, amount: $amount, reason: $reason) {
          id
          quantity {
            value
            unit
          }
          virtualAvailable
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'amount': amount, 'reason': reason},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null || result.data!['wasteInventoryItem'] == null) {
      throw Exception('Failed to waste inventory item');
    }

    return InventoryItem.fromJson(result.data!['wasteInventoryItem']);
  }

  Future<InventoryItem> getInventoryItem(String itemId) async {
    final fridges = await getMyFridges();
    for (final fridge in fridges) {
      for (final item in fridge.items) {
        if (item.id == itemId) {
          return item;
        }
      }
    }
    throw Exception('Inventory item $itemId not found');
  }
}
