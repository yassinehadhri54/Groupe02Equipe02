import '../../bookings/models/booking.dart';

enum MerchantOrderStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  rejected,
  unknown,
}

enum MerchantOrderAction { confirm, reject }

class MerchantOrder {
  const MerchantOrder({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    this.customerName,
    this.pickupDateTime,
    this.createdAt,
    this.paymentStatus,
  });

  factory MerchantOrder.fromJson(Map<String, dynamic> json) {
    final id = json['reservationId'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Réservation commerçant invalide.');
    }
    final offerId = json['offerId'];
    final quantity = _number(json['quantity']);
    final totalPrice = _number(json['totalPrice']);
    final offerName = json['offerName'];
    final paymentStatus = json['paymentStatus'];
    return MerchantOrder(
      id: id,
      offerId: offerId is String ? offerId : null,
      offerTitle: offerName is String ? offerName.trim() : '',
      quantity:
          quantity != null && quantity >= 0 && quantity == quantity.truncate()
          ? quantity.toInt()
          : null,
      totalPrice: totalPrice?.toDouble(),
      status: MerchantOrderStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => MerchantOrderStatus.unknown,
      ),
      createdAt: Booking.parseCreatedAt(json['createdAt']),
      paymentStatus: paymentStatus is String ? paymentStatus : null,
    );
  }

  final String id;
  final String? offerId;
  final String offerTitle;
  final String? customerName;
  final int? quantity;
  final double? totalPrice;
  final DateTime? pickupDateTime;
  final DateTime? createdAt;
  final MerchantOrderStatus status;
  final String? paymentStatus;

  String? get paymentStatusLabel => Booking.paymentLabelFor(paymentStatus);

  bool allows(MerchantOrderAction action) =>
      status == MerchantOrderStatus.pending &&
      switch (action) {
        MerchantOrderAction.confirm => paymentStatus == 'paid',
        MerchantOrderAction.reject => const {
          'unpaid',
          'failed',
        }.contains(paymentStatus),
      };

  static num? _number(Object? value) {
    final number = value is num
        ? value
        : value is String
        ? num.tryParse(value)
        : null;
    return number != null && number.isFinite ? number : null;
  }
}
