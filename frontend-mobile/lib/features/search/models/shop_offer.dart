import '../../offers/models/food_offer.dart';

class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.name,
    this.shopId,
    this.shopName,
    this.description,
    this.category,
    this.originalPrice,
    this.discountPrice,
    this.quantity,
    this.availableQuantity,
    this.imageUrl,
    this.pickupStart,
    this.pickupEnd,
    this.status,
    this.isExpired,
    this.isSoldOut,
  });

  factory ShopOffer.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['offerId']) ?? _stringValue(json['id']);
    final name = _stringValue(json['name']) ?? _stringValue(json['title']);

    if (id == null || name == null) {
      throw const FormatException('Required offer fields are missing.');
    }

    return ShopOffer(
      id: id,
      shopId: _stringValue(json['shopId']),
      shopName: _stringValue(json['shopName']),
      name: name,
      description: _stringValue(json['description']),
      category: _stringValue(json['category']),
      originalPrice: _doubleValue(json['originalPrice']),
      discountPrice: _doubleValue(
        json['discountPrice'] ?? json['discountedPrice'],
      ),
      quantity: _intValue(json['quantity']),
      availableQuantity: _intValue(json['availableQuantity']),
      imageUrl: _stringValue(json['imageURL']) ?? _stringValue(json['imageUrl']),
      pickupStart: _stringValue(json['pickupStart']),
      pickupEnd: _stringValue(json['pickupEnd']),
      status: _stringValue(json['status']),
      isExpired: _boolValue(json['isExpired']),
      isSoldOut: _boolValue(json['isSoldOut']),
    );
  }

  final String id;
  final String? shopId;
  final String? shopName;
  final String name;
  final String? description;
  final String? category;
  final double? originalPrice;
  final double? discountPrice;
  final int? quantity;
  final int? availableQuantity;
  final String? imageUrl;
  final String? pickupStart;
  final String? pickupEnd;
  final String? status;
  final bool? isExpired;
  final bool? isSoldOut;

  bool get isUnavailable =>
      isExpired == true ||
      isSoldOut == true ||
      (availableQuantity != null && availableQuantity! <= 0) ||
      (status != null && !{'available', 'active'}.contains(status));

  FoodOffer toFoodOffer() {
    final price = discountPrice;
    final oldPrice = originalPrice;
    if (price == null || oldPrice == null) {
      throw StateError('Offer prices are not available.');
    }

    return FoodOffer(
      name: name,
      shop: shopName ?? '',
      imageUrl: imageUrl ?? '',
      price: price,
      oldPrice: oldPrice,
      category: category ?? '',
      description: description ?? '',
    );
  }

  static String? _stringValue(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return value is String ? double.tryParse(value) : null;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return value is String ? int.tryParse(value) : null;
  }

  static bool? _boolValue(Object? value) => value is bool ? value : null;
}
