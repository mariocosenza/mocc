import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social_model.dart';

class SocialRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final socialRefreshProvider = NotifierProvider<SocialRefreshNotifier, int>(
  SocialRefreshNotifier.new,
);

class SocialService {
  final GraphQLClient client;

  SocialService(this.client);

  Future<List<Post>> getFeed({int limit = 20, int offset = 0}) async {
    const String query = r'''
      query Feed($limit: Int, $offset: Int) {
        feed(limit: $limit, offset: $offset) {
          id
          authorId
          authorNickname
          createdAt
          imageUrl
          caption
          likesCount
          likedBy
          recipeSnapshot {
             title
             description
             ingredients {
               name
               quantity
               unit
             }
             steps
             prepTimeMinutes
             calories
             ecoPointsReward
          }
          comments {
            id
            userId
            userNickname
            text
            createdAt
          }
        }
      }
    ''';

    final QueryOptions options = QueryOptions(
      document: gql(query),
      variables: {'limit': limit, 'offset': offset},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw result.exception!;
    }

    final List<dynamic> postsJson =
        result.data?['feed'] as List<dynamic>? ?? [];
    return postsJson
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost(CreatePostInput input) async {
    const String mutation = r'''
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
          authorId
          authorNickname
          createdAt
          imageUrl
          caption
          likesCount
          likedBy
          recipeSnapshot {
             title
             description
             ingredients {
               name
               quantity
               unit
             }
             steps
             prepTimeMinutes
             calories
             ecoPointsReward
          }
          comments {
            id
            userId
            userNickname
            text
            createdAt
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
      variables: {'id': id},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw result.exception!;
    }

    return result.data?['deletePost'] as bool? ?? false;
  }

  Future<Post> updatePost(String id, String caption) async {
    const String mutation = r'''
      mutation UpdatePost($id: ID!, $caption: String!) {
        updatePost(id: $id, caption: $caption) {
          id
          authorId
          authorNickname
          createdAt
          imageUrl
          caption
          likesCount
          likedBy
          recipeSnapshot {
             title
             description
             ingredients {
               name
               quantity
               unit
             }
             steps
             prepTimeMinutes
             calories
             ecoPointsReward
          }
          comments {
            id
            userId
            userNickname
            text
            createdAt
          }
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'caption': caption},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw result.exception!;
    }

    if (result.data == null || result.data!['updatePost'] == null) {
      throw Exception('Failed to update post');
    }

    return Post.fromJson(result.data!['updatePost']);
  }

  Future<Post> likePost(String id) async {
    const String mutation = r'''
      mutation LikePost($id: ID!) {
        likePost(postId: $id) {
          id
          authorId
          authorNickname
          createdAt
          imageUrl
          caption
          likesCount
          likedBy
          recipeSnapshot {
             title
             description
             ingredients {
               name
               quantity
               unit
             }
             steps
             prepTimeMinutes
             calories
             ecoPointsReward
          }
          comments {
            id
            userId
            userNickname
            text
            createdAt
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
      throw result.exception!;
    }

    if (result.data == null || result.data!['likePost'] == null) {
      throw Exception('Failed to like post');
    }

    return Post.fromJson(result.data!['likePost']);
  }

  Future<Post> unlikePost(String id) async {
    const String mutation = r'''
      mutation UnlikePost($id: ID!) {
        unlikePost(postId: $id) {
          id
          authorId
          authorNickname
          createdAt
          imageUrl
          caption
          likesCount
          likedBy
          recipeSnapshot {
             title
             description
             ingredients {
               name
               quantity
               unit
             }
             steps
             prepTimeMinutes
             calories
             ecoPointsReward
          }
          comments {
            id
            userId
            userNickname
            text
            createdAt
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
      throw result.exception!;
    }

    if (result.data == null || result.data!['unlikePost'] == null) {
      throw Exception('Failed to unlike post');
    }

    return Post.fromJson(result.data!['unlikePost']);
  }

  Future<Comment> addComment(String postId, String text) async {
    const String mutation = r'''
      mutation AddComment($postId: ID!, $text: String!) {
        addComment(postId: $postId, text: $text) {
          id
          userId
          userNickname
          text
          createdAt
        }
      }
    ''';

    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'postId': postId, 'text': text},
    );

    final QueryResult result = await client.mutate(options);

    if (result.hasException) {
      throw result.exception!;
    }

    if (result.data == null || result.data!['addComment'] == null) {
      throw Exception('Failed to add comment');
    }

    return Comment.fromJson(result.data!['addComment']);
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
      variables: {'top': top},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final QueryResult result = await client.query(options);

    if (result.hasException) {
      throw result.exception!;
    }

    final List<dynamic> leaderboardJson =
        result.data?['leaderboard'] as List<dynamic>? ?? [];
    return leaderboardJson
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> generateUploadSasToken(String filename) async {
    const String mutation = r'''
      mutation GenerateUploadSasToken($filename: String!, $purpose: UploadPurpose!) {
        generateUploadSasToken(filename: $filename, purpose: $purpose)
      }
    ''';
    final MutationOptions options = MutationOptions(
      document: gql(mutation),
      variables: {'filename': filename, 'purpose': 'SOCIAL_POST'},
    );
    final QueryResult result = await client.mutate(options);
    if (result.hasException) {
      throw result.exception!;
    }
    if (result.data == null || result.data!['generateUploadSasToken'] == null) {
      throw Exception('Failed to generate SAS token');
    }
    return result.data?['generateUploadSasToken'] as String;
  }
}
