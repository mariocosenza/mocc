import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/inventory_model.dart';

class InventoryService {
  final GraphQLClient client;

  InventoryService(this.client);

  Future<Fridge> getMyFridge() async {
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

    if (result.data == null || result.data!['myFridge'] == null) {
      throw Exception('Fridge not found');
    }

    return Fridge.fromJson(result.data!['myFridge']);
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
      variables: {
        'input': input.toJson(),
      },
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
      String id, UpdateInventoryItemInput input) async {
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
      variables: {
        'id': id,
        'input': input.toJson(),
      },
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
      variables: {
        'id': id,
      },
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
      variables: {
        'id': id,
        'amount': amount,
      },
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

     if (result.data == null || result.data!['consumeInventoryItem'] == null) {
      throw Exception('Failed to consume inventory item');
    }

    // Only partial data returned by mutation usually, but here we ask for Quantity. 
    // Usually consuming returns the updated item.
    // Assuming backend returns full object or client refetches.
    // For now we map what we get. The return type is InventoryItem.
    // Note: If you want full object, expand the mutation selection set. 
    // I expanded it slightly.
    return InventoryItem.fromJson(result.data!['consumeInventoryItem']);
  }

  Future<InventoryItem> wasteInventoryItem(
      String id, double amount, String? reason) async {
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
      variables: {
        'id': id,
        'amount': amount,
        'reason': reason,
      },
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
}
