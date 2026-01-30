import 'enums.dart';

class ShoppingHistoryEntry {
  final String id;
  final DateTime date;
  final String? storeName;
  final double? totalAmount;
  final String currency;
  final String? receiptImageUrl;
  final bool isImported;
  final List<HistoryItem> itemsSnapshot;
  final ShoppingHistoryStatus status;

  ShoppingHistoryEntry({
    required this.id,
    required this.date,
    this.storeName,
    this.totalAmount,
    required this.currency,
    this.receiptImageUrl,
    required this.isImported,
    required this.itemsSnapshot,
    required this.status,
  });

  factory ShoppingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ShoppingHistoryEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      storeName: json['storeName'] as String?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      receiptImageUrl: json['receiptImageUrl'] as String?,
      isImported: json['isImported'] as bool? ?? false,
      itemsSnapshot:
          (json['itemsSnapshot'] as List<dynamic>?)
              ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: ShoppingHistoryStatus.fromJson(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'storeName': storeName,
    'totalAmount': totalAmount,
    'currency': currency,
    'receiptImageUrl': receiptImageUrl,
    'isImported': isImported,
    'itemsSnapshot': itemsSnapshot.map((e) => e.toJson()).toList(),
    'status': status.toJson(),
  };
}

class HistoryItem {
  final String? id;
  final String name;
  final double? price;
  final double? quantity;
  final Unit? unit;
  final String? category;
  final String? brand;
  final DateTime? expiryDate;
  final ExpiryType? expiryType;
  final double? confidence;

  HistoryItem({
    this.id,
    required this.name,
    this.price,
    this.quantity,
    this.unit,
    this.category,
    this.brand,
    this.expiryDate,
    this.expiryType,
    this.confidence,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] != null
          ? Unit.values.firstWhere(
              (e) =>
                  e.name.toUpperCase() == json['unit'].toString().toUpperCase(),
              orElse: () => Unit.pz,
            )
          : null,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      expiryType: json['expiryType'] != null
          ? ExpiryType.fromJson(json['expiryType'] as String)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
    'unit': unit?.name.toUpperCase(),
    'category': category,
    'brand': brand,
    'expiryDate': expiryDate?.toIso8601String(),
    'expiryType': expiryType?.toJson(),
    'confidence': confidence,
  };
}
