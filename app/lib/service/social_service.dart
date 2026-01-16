import 'package:graphql_flutter/graphql_flutter.dart';
import '../models/social_model.dart';

class SocialService {
  final GraphQLClient client;

  SocialService(this.client);

  Future<List<Post>> getFeed({int limit = 20, int offset = 0}) async {
    const String query = r'''
      query Feed($limit: Int, $offset: Int) {
        feed(limit: $limit, offset: $offset) {
          id
          author {
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
          }
          createdAt
          imageUrl
          caption
          likesCount
          isLikedByMe
          recipeSnapshot {
             id
             authorId
             title
             description
             status
             ingredients {
               name
               quantity
               unit
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
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {
        'limit': limit,
        'offset': offset,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> postsJson = result.data?['feed'] as List<dynamic>? ?? [];
    return postsJson
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaderboardEntry>> getLeaderboard({int top = 50}) async {
    const String query = r'''
      query Leaderboard($top: Int) {
        leaderboard(top: $top) {
          rank
          nickname
          score
        }
      }
    ''';
    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {
        'top': top,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final List<dynamic> leaderboardJson =
        result.data?['leaderboard'] as List<dynamic>? ?? [];
    return leaderboardJson
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost(CreatePostInput input) async {
    const String mutation = r'''
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
          author {
            id
            nickname
            avatarUrl
          }
          createdAt
          imageUrl
          caption
          likesCount
          isLikedByMe
          recipeSnapshot {
            id
            title
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

    if (result.data == null || result.data!['createPost'] == null) {
      throw Exception('Failed to create post');
    }

    return Post.fromJson(result.data!['createPost']);
  }

  Future<bool> deletePost(String id) async {
    const String mutation = r'''
      mutation DeletePost($id: ID!) {
        deletePost(id: $id)
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

    return result.data?['deletePost'] as bool? ?? false;
  }

  Future<Post> likePost(String id) async {
    const String mutation = r'''
      mutation LikePost($id: ID!) {
        likePost(id: $id) {
          id
          likesCount
          isLikedByMe
        }
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

    if (result.data == null || result.data!['likePost'] == null) {
      throw Exception('Failed to like post');
    }

    return Post.fromJson(result.data!['likePost']);
  }

  Future<Post> unlikePost(String id) async {
    const String mutation = r'''
      mutation UnlikePost($id: ID!) {
        unlikePost(id: $id) {
          id
          likesCount
          isLikedByMe
        }
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

    if (result.data == null || result.data!['unlikePost'] == null) {
      throw Exception('Failed to unlike post');
    }

    return Post.fromJson(result.data!['unlikePost']);
  }
}
