import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final GraphQLClient client;

  UserService(this.client);

  Future<User> getMe() async {
    const String query = r'''
      query Me {
        me {
          id
          email
          nickname
          avatarUrl
          origin
          gamification {
            totalEcoPoints
            currentLevel
            nextLevelThreshold
            badges
            wastedMoneyYTD
          }
          preferences {
            dietaryRestrictions
            defaultPortions
            currency
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
      throw result.exception!;
    }

    if (result.data == null || result.data!['me'] == null) {
      throw Exception('User not found');
    }

    return User.fromJson(result.data!['me']);
  }

  Future<String> getUserId() async {
    const String query = r'''
      query GetUserNickname {
        me {
          id
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw result.exception!;
    }

    if (result.data == null || result.data!['me'] == null) {
      throw Exception('User not found');
    }

    return result.data!['me']['id'] as String;
  }

  Future<UserPreferences> getUserPreferences() async {
    const String query = r'''
      query GetUserPreferences {
        me {
          preferences {
            dietaryRestrictions
            defaultPortions
            currency
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
      throw result.exception!;
    }

    if (result.data == null ||
        result.data!['me'] == null ||
        result.data!['me']['preferences'] == null) {
      throw Exception('User preferences not found');
    }

    return UserPreferences.fromJson(result.data!['me']['preferences']);
  }

  Future<User> updateUserPreferences(UserPreferencesInput input) async {
    const String mutation = r'''
      mutation UpdateUserPreferences($input: UserPreferencesInput!) {
        updateUserPreferences(input: $input) {
          id
          email
          nickname
          avatarUrl
          origin
          gamification {
            totalEcoPoints
            currentLevel
            nextLevelThreshold
            badges
            wastedMoneyYTD
          }
          preferences {
            dietaryRestrictions
            defaultPortions
            currency
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
      throw result.exception!;
    }

    if (result.data == null || result.data!['updateUserPreferences'] == null) {
      throw Exception('Failed to update user preferences');
    }

    return User.fromJson(result.data!['updateUserPreferences']);
  }

  Future<void> updateNickname(String newNickname) async {
    const String mutation = r'''
      mutation UpdateUserPreferences($newNickname: String!) {
        updateNickname(nickname: $newNickname) {
          nickname
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'newNickname': newNickname},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw result.exception!;
    }
  }

  Future<void> registerDevice(String handle, String platform) async {
    const String mutation = r'''
      mutation RegisterDevice($handle: String!, $platform: String!) {
        registerDevice(handle: $handle, platform: $platform)
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'handle': handle, 'platform': platform},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw result.exception!;
    }
  }
}
