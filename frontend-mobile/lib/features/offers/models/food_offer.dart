class FoodOffer {
  const FoodOffer({
    required this.name,
    required this.shop,
    required this.imageUrl,
    required this.price,
    required this.oldPrice,
    required this.category,
    required this.description,
  });

  final String name;
  final String shop;
  final String imageUrl;
  final double price;
  final double oldPrice;
  final String category;
  final String description;
}
