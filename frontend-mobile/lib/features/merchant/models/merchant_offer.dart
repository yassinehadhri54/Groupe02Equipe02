class MerchantOffer {
  const MerchantOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.originalPrice,
    required this.discountedPrice,
    required this.quantityAvailable,
    required this.pickupStart,
    required this.pickupEnd,
    required this.isActive,
    required this.createdAt,
  }) : assert(quantityAvailable >= 0);

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final double originalPrice;
  final double discountedPrice;
  final int quantityAvailable;
  final DateTime pickupStart;
  final DateTime pickupEnd;
  final bool isActive;
  final DateTime createdAt;

  MerchantOffer copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    double? originalPrice,
    double? discountedPrice,
    int? quantityAvailable,
    DateTime? pickupStart,
    DateTime? pickupEnd,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return MerchantOffer(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      originalPrice: originalPrice ?? this.originalPrice,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      quantityAvailable: quantityAvailable ?? this.quantityAvailable,
      pickupStart: pickupStart ?? this.pickupStart,
      pickupEnd: pickupEnd ?? this.pickupEnd,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
