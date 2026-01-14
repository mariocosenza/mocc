import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/models/user_model.dart';
import 'package:mocc/service/graphql_config.dart';

final userGraphQLServiceProvider = Provider<UserGraphQLService>((ref) {
  final client = ref.watch(graphQLClientProvider);
  return UserGraphQLService(client);
});

class UserGraphQLService {
  final GraphQLClient client;

  UserGraphQLService(this.client);

  Future<UserPreferences> getPreference() async {
      try {
        QueryResult result = await client.query(
          QueryOptions(fetchPolicy: FetchPolicy.noCache,
            document: gql("""

        """) 
          )
        );

        if (result.hasException) {
          throw Exception(result.exception.toString());
        }

        return UserPreferences.fromJson(result.data!);
      } catch(e) {
        throw Exception(e);
      }

  }

  

    Future<User> getUser() async {
      try {
        QueryResult result = await client.query(
          QueryOptions(fetchPolicy: FetchPolicy.noCache,
            document: gql("""

        """) 
          )
        );

        if (result.hasException) {
          throw Exception(result.exception.toString());
        }

        return User.fromJson(result.data!);
      } catch(e) {
        throw Exception(e);
      }

  }



}