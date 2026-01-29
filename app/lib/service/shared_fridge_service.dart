import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/inventory_model.dart';

class SharedFridgeService {
  final GraphQLClient client;

  SharedFridgeService(this.client);

  Future<SharedFridgeLink> generateSharedFridgeLink() async {
    const String mutation = r'''
      mutation GenerateSharedFridgeLink {
        generateSharedFridgeLink {
          authorId
          inviteCode
        }
      }
    ''';

    final MutationOptions options = MutationOptions(document: gql(mutation));

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    if (result.data == null ||
        result.data!['generateSharedFridgeLink'] == null) {
      throw Exception('Failed to generate shared fridge link');
    }

    return SharedFridgeLink.fromJson(result.data!['generateSharedFridgeLink']);
  }

  Future<String?> addFridgeShared(String inviteCode) async {
    const String mutation = r'''
      mutation AddFridgeShared($sharedId: ID) {
        addFridgeShared(sharedId: $sharedId)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'sharedId': inviteCode},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      // Check if it's a specific error we want to handle gracefully, otherwise throw
      throw Exception(result.exception.toString());
    }

    // The mutation returns ID, which matches the signature in schema: addFridgeShared(sharedId: ID): ID
    // If it returns null, it might mean failure or just no ID returned (schema says ID, usually nullable if failed? wait schema says ID, implied nullable? no, checks schema)
    // schema: addFridgeShared(sharedId: ID): ID

    return result.data?['addFridgeShared'] as String?;
  }
}
