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
        return ExpiryType.expiration;
      case 'BEST_BEFORE':
        return ExpiryType.bestBefore;
      default:
        throw ArgumentError('Unknown ExpiryType: $json');
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

enum Currency {
  usd,
  eur;

  String toJson() => name.toUpperCase();

  static Currency fromJson(String json) => values.byName(json.toLowerCase());
}