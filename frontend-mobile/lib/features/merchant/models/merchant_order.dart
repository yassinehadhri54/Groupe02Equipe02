enum MerchantOrderStatus { pending, confirmed, completed, cancelled }

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.customerName,
    required this.quantity,
    required this.totalPrice,
    required this.pickupDateTime,
    required this.status,
  }) : assert(quantity >= 1);

  final String id;
  final String offerId;
  final String offerTitle;
  final String customerName;
  final int quantity;
  final double totalPrice;
  final DateTime pickupDateTime;
  final MerchantOrderStatus status;
}
