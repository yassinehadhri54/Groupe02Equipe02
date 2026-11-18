class Booking {
  const Booking({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.image,
    required this.price,
    required this.oldPrice,
    required this.quantity,
    required this.date,
    required this.pickup,
    required this.address,
    required this.instructions,
    required this.status,
    this.pickupCode,
  }) : assert(quantity >= 1);

  final String id;
  final String name;
  final String restaurant;
  final String image;
  final double price;
  final double oldPrice;
  final int quantity;
  final String date;
  final String pickup;
  final String address;
  final String instructions;
  final String status;
  final String? pickupCode;
}
