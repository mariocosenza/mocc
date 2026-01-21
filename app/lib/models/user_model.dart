import 'enums.dart';

class User {
  final String id;
  final String email;
  final String nickname; 
  final String? avatarUrl;
  final AccountOrigin origin;
  final GamificationProfile gamification;
  final UserPreferences? preferences;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    required this.origin,
    required this.gamification,
    this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      origin: AccountOrigin.fromJson(json['origin'] as String),
      gamification: GamificationProfile.fromJson(json['gamification'] as Map<String, dynamic>),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'origin': origin.toJson(),
        'gamification': gamification.toJson(),
        'preferences': preferences?.toJson(),
      };
}

class GamificationProfile {
  final int totalEcoPoints;
  final int currentLevel; 
  final int nextLevelThreshold;
  final List<String> badges;
  final double? wastedMoneyYTD;

  GamificationProfile({
    required this.totalEcoPoints,
    required this.currentLevel,
    required this.nextLevelThreshold,
    required this.badges,
    this.wastedMoneyYTD,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      totalEcoPoints: json['totalEcoPoints'] as int,
      currentLevel: json['currentLevel'] is int
          ? json['currentLevel'] as int
          : int.parse(json['currentLevel'].toString()),
      nextLevelThreshold: json['nextLevelThreshold'] as int,
      badges: (json['badges'] as List<dynamic>?)?.cast<String>() ?? [],
      wastedMoneyYTD: (json['wastedMoneyYTD'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalEcoPoints': totalEcoPoints,
        'currentLevel': currentLevel,
        'nextLevelThreshold': nextLevelThreshold,
        'badges': badges,
        'wastedMoneyYTD': wastedMoneyYTD,
      };
}

class UserPreferences {
  final List<String>? dietaryRestrictions;
  final int? defaultPortions;
  final Currency currency;

  UserPreferences({
    this.dietaryRestrictions,
    this.defaultPortions,
    required this.currency,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      defaultPortions: json['defaultPortions'] as int?,
      currency: Currency.fromJson(json['currency'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'dietaryRestrictions': dietaryRestrictions,
        'defaultPortions': defaultPortions,
        'currency': currency.toJson(),
      };
}

class UserPreferencesInput {
  final List<String>? dietaryRestrictions;
  final int? defaultPortions;
  final Currency? currency;

  UserPreferencesInput({
    this.dietaryRestrictions,
    this.defaultPortions,
    this.currency,
  });

  Map<String, dynamic> toJson() => {
        if (dietaryRestrictions != null)
          'dietaryRestrictions': dietaryRestrictions,
        if (defaultPortions != null) 'defaultPortions': defaultPortions,
        if (currency != null) 'currency': currency!.toJson(),
      };
}