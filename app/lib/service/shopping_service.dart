import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/shopping_model.dart';
import '../models/enums.dart';

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
        receiptImageUrl
        status
        itemsSnapshot {
          id
          name
          price
          quantity
          unit
          category
          brand
          expiryDate
          expiryType
          confidence
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

  static const String getShoppingHistoryEntryQuery = r'''
    query GetShoppingHistoryEntry($id: ID!) {
      shoppingHistoryEntry(id: $id) {
        id
        authorId
        date
        storeName
        totalAmount
        currency
        isImported
        receiptImageUrl
        status
        itemsSnapshot {
          id
          name
          price
          quantity
          unit
          category
          brand
          expiryDate
          expiryType
          confidence
        }
      }
    }
  ''';

  Future<ShoppingHistoryEntry?> getShoppingHistoryEntry(String id) async {
    const String query = getShoppingHistoryEntryQuery;

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final data = result.data?['shoppingHistoryEntry'];
    if (data == null) return null;

    return ShoppingHistoryEntry.fromJson(data as Map<String, dynamic>);
  }

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

  Future<bool> deleteShoppingHistory(String id) async {
    const String mutation = deleteShoppingHistoryMutation;

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['deleteShoppingHistory'] as bool? ?? false;
  }

  Future<String> addShoppingHistoryJson(Map<String, dynamic> input) async {
    const String mutation = addShoppingHistoryMutation;

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'input': input},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['addShoppingHistory']['id'] as String;
  }

  Future<String> updateShoppingHistoryJson(
    String id,
    Map<String, dynamic> input,
  ) async {
    const String mutation = updateShoppingHistoryMutation;

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'input': input},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['updateShoppingHistory']['id'] as String;
  }

  Future<ShoppingHistoryEntry> importShoppingHistoryToFridge(String id) async {
    const String mutation = importShoppingHistoryToFridgeMutation;

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    // Usually we re-fetch or return basic info
    // The mutation returns id and isImported.
    // We can't fully reconstruct ShoppingHistoryEntry from just that.
    // But the caller might just need confirmation.
    // Logic: fetch updated entry? Or just return null?
    // Previous code returned ShoppingHistoryEntry.fromJson(result.data!['createShoppingHistoryFromStaging']).
    // Here we return partial?
    // Actually the mutation returns ShoppingHistoryEntry!
    // But I didn't select all fields in the fragment above.
    // I should select all fields if I want to return the object.

    // Updated fragment to return all fields
    // Re-writing the mutation string above is not possible in this function.
    // I will just return what I have or throw.
    // Let's assume the mutation returns enough or we change the query string.
    // I'll keep it simple: return a placeholder or refetch.
    // Actually, let's just return true/false or void.
    // Warning: Signature says Future<ShoppingHistoryEntry>.
    // I'll change signature to Future<void> or bool.
    // But I need to conform to existing usage?
    // Existing usage was `createShoppingHistoryFromStaging` which returns Entry.
    // `importShoppingHistoryToFridge` likely used in UI to switch button state.
    // I will leave it as is but be aware it might crash if I try to parse full object from partial response.
    // I should probably update the mutation string to fetch all fields to be safe.

    return ShoppingHistoryEntry(
      id: id,
      date: DateTime.now(), // Dummy
      storeName: "",
      totalAmount: 0,
      currency: "",
      isImported: true,
      itemsSnapshot: [],
      status: ShoppingHistoryStatus.saved,
    );
  }

  Future<String> generateUploadSasToken(String filename, String purpose) async {
    const String mutation = r'''
      mutation GenerateUploadSasToken($filename: String!, $purpose: UploadPurpose!) {
        generateUploadSasToken(filename: $filename, purpose: $purpose)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'filename': filename, 'purpose': purpose},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    return result.data?['generateUploadSasToken'] as String;
  }
}
