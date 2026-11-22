class ShopSummary {
  const ShopSummary({
    required this.id,
    required this.name,
    required this.categories,
    required this.availableOfferCount,
  });

  final String id;
  final String name;
  final List<String> categories;
  final int availableOfferCount;
}
