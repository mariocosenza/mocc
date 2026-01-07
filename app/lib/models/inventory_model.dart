import 'enums.dart';

class Fridge {
  final String id;
  final String name;
  final String ownerId;
  final List<InventoryItem> items;

  Fridge({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.items,
  });

  factory Fridge.fromJson(Map<String, dynamic> json) {
    return Fridge(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class InventoryItem {
  final String id;
  final String name;
  final String? brand;
  final String? category;
  final Quantity quantity;
  final double virtualAvailable;
  final DateTime expiryDate;
  final ExpiryType expiryType;
  final DateTime addedAt;
  final List<ProductLock>? activeLocks;

  InventoryItem({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    required this.quantity,
    required this.virtualAvailable,
    required this.expiryDate,
    required this.expiryType,
    required this.addedAt,
    this.activeLocks,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      quantity: Quantity.fromJson(json['quantity'] as Map<String, dynamic>),
      virtualAvailable: (json['virtualAvailable'] as num).toDouble(),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      expiryType: ExpiryType.fromJson(json['expiryType'] as String),
      addedAt: DateTime.parse(json['addedAt'] as String),
      activeLocks: json['activeLocks'] != null
          ? (json['activeLocks'] as List<dynamic>)
              .map((e) => ProductLock.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'quantity': quantity.toJson(),
        'virtualAvailable': virtualAvailable,
        'expiryDate': expiryDate.toIso8601String(),
        'expiryType': expiryType.toJson(),
        'addedAt': addedAt.toIso8601String(),
        'activeLocks': activeLocks?.map((e) => e.toJson()).toList(),
      };
}

class Quantity {
  final double value;
  final Unit unit;

  Quantity({
    required this.value,
    required this.unit,
  });

  factory Quantity.fromJson(Map<String, dynamic> json) {
    return Quantity(
      value: (json['value'] as num).toDouble(),
      unit: Unit.fromJson(json['unit'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'unit': unit.toJson(),
      };
}

class ProductLock {
  final String recipeId;
  final double amount;
  final DateTime startedAt;

  ProductLock({
    required this.recipeId,
    required this.amount,
    required this.startedAt,
  });

  factory ProductLock.fromJson(Map<String, dynamic> json) {
    return ProductLock(
      recipeId: json['recipeId'] as String,
      amount: (json['amount'] as num).toDouble(),
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'amount': amount,
        'startedAt': startedAt.toIso8601String(),
      };
}