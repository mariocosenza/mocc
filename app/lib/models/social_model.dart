import 'recipe_model.dart';
import 'user_model.dart';

class Post {
  final String id;
  final User author;
  final DateTime createdAt;
  final String imageUrl;
  final String? caption;
  final int likesCount;
  final bool isLikedByMe;
  final Recipe recipeSnapshot;

  Post({
    required this.id,
    required this.author,
    required this.createdAt,
    required this.imageUrl,
    this.caption,
    required this.likesCount,
    required this.isLikedByMe,
    required this.recipeSnapshot,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrl: json['imageUrl'] as String,
      caption: json['caption'] as String?,
      likesCount: json['likesCount'] as int,
      isLikedByMe: json['isLikedByMe'] as bool,
      recipeSnapshot: Recipe.fromJson(json['recipeSnapshot'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'imageUrl': imageUrl,
        'caption': caption,
        'likesCount': likesCount,
        'isLikedByMe': isLikedByMe,
        'recipeSnapshot': recipeSnapshot.toJson(),
      };
}

class LeaderboardEntry {
  final int rank;
  final User user;
  final int score;

  LeaderboardEntry({
    required this.rank,
    required this.user,
    required this.score,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'user': user.toJson(),
        'score': score,
      };
}

class CreatePostInput {
  final String recipeId;
  final String? caption;
  final String? imageUrl;

  CreatePostInput({
    required this.recipeId,
    this.caption,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'caption': caption,
        'imageUrl': imageUrl,
      };
}