import 'package:flutter/cupertino.dart';

enum AccountOrigin {
  microsoft,
  google,
  apple;

  String toJson() => name.toUpperCase();

  static AccountOrigin fromJson(String json) =>
      values.byName(json.toLowerCase());
}

enum Unit {
  g,
  kg,
  ml,
  l,
  pz,
  qb;

  String toJson() => name.toUpperCase();
  @override
  String toString() => name.toUpperCase();

  static Unit fromJson(String json) => values.byName(json.toLowerCase());
}

enum ExpiryType {
  expiration,
  bestBefore;

  String toJson() {
    switch (this) {
      case ExpiryType.expiration:
        return 'EXPIRATION';
      case ExpiryType.bestBefore:
        return 'BEST_BEFORE';
    }
  }

  static ExpiryType fromJson(String json) {
    switch (json) {
      case 'EXPIRATION':
      case 'expiration':
      case 'expiry_date':
      case 'Data di scadenza':
        return ExpiryType.expiration;
      case 'BEST_BEFORE':
      case 'best_before':
      case 'bestBefore':
      case 'Prefiribilemente entro':
        return ExpiryType.bestBefore;
      default:
        // Fallback or fuzzy match
        final lower = json.toLowerCase();
        if (lower.contains('best')) return ExpiryType.bestBefore;
        if (lower.contains('exp')) return ExpiryType.expiration;
        debugPrint(
          'Warning: Unknown ExpiryType: $json, defaulting to bestBefore',
        );
        return ExpiryType.bestBefore;
    }
  }
}

enum ItemStatus {
  available,
  consumed,
  wasted,
  inStaging;

  String toJson() {
    switch (this) {
      case ItemStatus.available:
        return 'AVAILABLE';
      case ItemStatus.consumed:
        return 'CONSUMED';
      case ItemStatus.wasted:
        return 'WASTED';
      case ItemStatus.inStaging:
        return 'IN_STAGING';
    }
  }

  static ItemStatus fromJson(String json) {
    switch (json) {
      case 'AVAILABLE':
        return ItemStatus.available;
      case 'CONSUMED':
        return ItemStatus.consumed;
      case 'WASTED':
        return ItemStatus.wasted;
      case 'IN_STAGING':
        return ItemStatus.inStaging;
      default:
        throw ArgumentError('Unknown ItemStatus: $json');
    }
  }
}

enum RecipeStatus {
  proposed,
  saved,
  inPreparation,
  cooked;

  String toJson() {
    switch (this) {
      case RecipeStatus.proposed:
        return 'PROPOSED';
      case RecipeStatus.saved:
        return 'SAVED';
      case RecipeStatus.inPreparation:
        return 'IN_PREPARATION';
      case RecipeStatus.cooked:
        return 'COOKED';
    }
  }

  static RecipeStatus fromJson(String json) {
    switch (json) {
      case 'PROPOSED':
        return RecipeStatus.proposed;
      case 'SAVED':
        return RecipeStatus.saved;
      case 'IN_PREPARATION':
        return RecipeStatus.inPreparation;
      case 'COOKED':
        return RecipeStatus.cooked;
      default:
        throw ArgumentError('Unknown RecipeStatus: $json');
    }
  }
}

enum ShoppingHistoryStatus {
  inStaging,
  saved,
  deleted;

  String toJson() {
    switch (this) {
      case ShoppingHistoryStatus.inStaging:
        return 'IN_STAGING';
      case ShoppingHistoryStatus.saved:
        return 'SAVED';
      case ShoppingHistoryStatus.deleted:
        return 'DELETED';
    }
  }

  static ShoppingHistoryStatus fromJson(String json) {
    switch (json.toUpperCase()) {
      case 'IN_STAGING':
        return ShoppingHistoryStatus.inStaging;
      case 'SAVED':
        return ShoppingHistoryStatus.saved;
      case 'DELETED':
        return ShoppingHistoryStatus.deleted;
      default:
        debugPrint(
          'Warning: Unknown ShoppingHistoryStatus: $json, defaulting to saved',
        );
        return ShoppingHistoryStatus.saved;
    }
  }
}

enum Currency {
  usd,
  eur;

  String toJson() => name.toUpperCase();

  static Currency fromJson(String json) => values.byName(json.toLowerCase());
}
