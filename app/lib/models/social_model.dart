import 'enums.dart';

class RecipeSnapshot {
  final String title;
  final String? description;
  final List<RecipeIngredientSnapshot> ingredients;
  final List<String> steps;
  final int? prepTimeMinutes;
  final int? calories;
  final int? ecoPointsReward;

  RecipeSnapshot({
    required this.title,
    this.description,
    required this.ingredients,
    required this.steps,
    this.prepTimeMinutes,
    this.calories,
    this.ecoPointsReward,
  });

  factory RecipeSnapshot.fromJson(Map<String, dynamic> json) {
    return RecipeSnapshot(
      title: json['title'] as String,
      description: json['description'] as String?,
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map(
                (e) => RecipeIngredientSnapshot.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      steps:
          (json['steps'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      calories: json['calories'] as int?,
      ecoPointsReward: json['ecoPointsReward'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'steps': steps,
    'prepTimeMinutes': prepTimeMinutes,
    'calories': calories,
    'ecoPointsReward': ecoPointsReward,
  };
}

class RecipeIngredientSnapshot {
  final String name;
  final double quantity;
  final Unit unit;

  RecipeIngredientSnapshot({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredientSnapshot.fromJson(Map<String, dynamic> json) {
    return RecipeIngredientSnapshot(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: Unit.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toUpperCase() ==
            (json['unit'] as String).toUpperCase(),
        orElse: () => Unit.pz,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit.toString().split('.').last.toUpperCase(),
  };
}

class Comment {
  final String id;
  final String userId;
  final String userNickname;
  final String text;
  final DateTime createdAt;
  final bool removed;

  Comment({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.text,
    required this.createdAt,
    required this.removed,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userNickname: json['userNickname'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      removed: json['removed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userNickname': userNickname,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'removed': removed,
  };
}

class Post {
  final String id;
  final String authorId;
  final String authorNickname;
  final DateTime createdAt;
  final String? imageUrl;
  final String? caption;
  final int likesCount;
  final List<String> likedBy;
  final RecipeSnapshot recipeSnapshot;
  final List<Comment> comments;

  Post({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.createdAt,
    this.imageUrl,
    this.caption,
    required this.likesCount,
    required this.likedBy,
    required this.recipeSnapshot,
    required this.comments,
  });

  bool isLikedBy(String userId) => likedBy.contains(userId);

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorNickname: json['authorNickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      imageUrl: json['imageUrl'] as String?,
      caption: json['caption'] as String?,
      likesCount: json['likesCount'] as int,
      likedBy:
          (json['likedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recipeSnapshot: RecipeSnapshot.fromJson(
        json['recipeSnapshot'] as Map<String, dynamic>,
      ),
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorNickname': authorNickname,
    'createdAt': createdAt.toIso8601String(),
    'imageUrl': imageUrl,
    'caption': caption,
    'likesCount': likesCount,
    'likedBy': likedBy,
    'recipeSnapshot': recipeSnapshot.toJson(),
    'comments': comments.map((e) => e.toJson()).toList(),
  };
}

class LeaderboardEntry {
  final int rank;
  final String nickname;
  final int score;

  LeaderboardEntry({
    required this.rank,
    required this.nickname,
    required this.score,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      nickname: json['nickname'] as String,
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'nickname': nickname,
    'score': score,
  };
}

class CreatePostInput {
  final String recipeId;
  final String? caption;
  final String? imageUrl;

  CreatePostInput({required this.recipeId, this.caption, this.imageUrl});

  Map<String, dynamic> toJson() => {
    'recipeId': recipeId,
    'caption': caption,
    'imageUrl': imageUrl,
  };
}
