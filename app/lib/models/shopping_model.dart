import 'enums.dart';

class StagingSession {
  final String id;
  final String? detectedStore;
  final double? detectedTotal;
  final List<StagingItem> items;
  final DateTime createdAt;
  final DateTime expiresAt;

  StagingSession({
    required this.id,
    this.detectedStore,
    this.detectedTotal,
    required this.items,
    required this.createdAt,
    required this.expiresAt,
  });

  factory StagingSession.fromJson(Map<String, dynamic> json) {
    return StagingSession(
      id: json['id'] as String,
      detectedStore: json['detectedStore'] as String?,
      detectedTotal: (json['detectedTotal'] as num?)?.toDouble(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => StagingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'detectedStore': detectedStore,
    'detectedTotal': detectedTotal,
    'items': items.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

class StagingItem {
  final String id;
  final String name;
  final double? detectedPrice;
  final int? quantity;
  final double? confidence;

  StagingItem({
    required this.id,
    required this.name,
    this.detectedPrice,
    this.quantity,
    this.confidence,
  });

  factory StagingItem.fromJson(Map<String, dynamic> json) {
    return StagingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      detectedPrice: (json['detectedPrice'] as num?)?.toDouble(),
      quantity: json['quantity'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'detectedPrice': detectedPrice,
    'quantity': quantity,
    'confidence': confidence,
  };
}

class StagingItemInput {
  final String? name;
  final double? detectedPrice;
  final int? quantity;

  StagingItemInput({this.name, this.detectedPrice, this.quantity});

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (detectedPrice != null) 'detectedPrice': detectedPrice,
    if (quantity != null) 'quantity': quantity,
  };
}

class ShoppingHistoryEntry {
  final String id;
  final DateTime date;
  final String storeName;
  final double totalAmount;
  final String currency;
  final String? receiptImageUrl;
  final List<HistoryItem> itemsSnapshot;

  ShoppingHistoryEntry({
    required this.id,
    required this.date,
    required this.storeName,
    required this.totalAmount,
    required this.currency,
    this.receiptImageUrl,
    required this.itemsSnapshot,
  });

  factory ShoppingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      storeName: json['storeName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      receiptImageUrl: json['receiptImageUrl'] as String?,
      itemsSnapshot: (json['itemsSnapshot'] as List<dynamic>)
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'storeName': storeName,
    'totalAmount': totalAmount,
    'currency': currency,
    'receiptImageUrl': receiptImageUrl,
    'itemsSnapshot': itemsSnapshot.map((e) => e.toJson()).toList(),
  };
}

class HistoryItem {
  final String name;
  final double price;
  final double quantity;
  final Unit unit;
  final String? category;
  final String? brand;
  final DateTime expiryDate;
  final ExpiryType expiryType;

  HistoryItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    this.category,
    this.brand,
    required this.expiryDate,
    required this.expiryType,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      unit: Unit.values.firstWhere((e) => e.name == json['unit']),
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      expiryType: ExpiryType.fromJson(json['expiryType'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
    'unit': unit.name,
    'category': category,
    'brand': brand,
    'expiryDate': expiryDate.toIso8601String(),
    'expiryType': expiryType.toJson(),
  };
}
