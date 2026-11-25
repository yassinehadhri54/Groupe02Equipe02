enum ReservationStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed,
  unknown,
}

class Booking {
  const Booking({
    required this.id,
    required this.offerId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    this.restaurant,
    this.paymentStatus,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['reservationId']) ?? _stringValue(json['id']);
    final offerId = _stringValue(json['offerId']);
    final name = _stringValue(json['offerName']) ?? _stringValue(json['name']);
    final quantity = _intValue(json['quantity']);
    final unitPrice = _doubleValue(json['unitPrice'] ?? json['price']);

    if (id == null ||
        offerId == null ||
        name == null ||
        quantity == null ||
        quantity < 1 ||
        unitPrice == null) {
      throw const FormatException('Required reservation fields are missing.');
    }

    final totalPrice = _doubleValue(json['totalPrice']) ?? unitPrice * quantity;

    return Booking(
      id: id,
      offerId: offerId,
      name: name,
      restaurant: _stringValue(json['shopName']),
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      status: _stringValue(json['status'])?.toLowerCase() ?? 'unknown',
      paymentStatus: _stringValue(json['paymentStatus'])?.toLowerCase(),
      createdAt: parseCreatedAt(json['createdAt']),
    );
  }

  final String id;
  final String offerId;
  final String name;
  final String? restaurant;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status;
  final String? paymentStatus;
  final DateTime? createdAt;

  ReservationStatus get parsedStatus => switch (status) {
    'pending' => ReservationStatus.pending,
    'confirmed' => ReservationStatus.confirmed,
    'rejected' => ReservationStatus.rejected,
    'cancelled' => ReservationStatus.cancelled,
    'completed' => ReservationStatus.completed,
    _ => ReservationStatus.unknown,
  };

  String get statusLabel => switch (parsedStatus) {
    ReservationStatus.pending => 'En attente',
    ReservationStatus.confirmed => 'Confirmée',
    ReservationStatus.rejected => 'Refusée',
    ReservationStatus.cancelled => 'Annulée',
    ReservationStatus.completed => 'Terminée',
    ReservationStatus.unknown => status,
  };

  String? get paymentStatusLabel => paymentLabelFor(paymentStatus);

  static String? paymentLabelFor(String? value) {
    if (value == null) return null;
    return switch (value) {
      'unpaid' => 'Non payé',
      'pending' || 'processing' => 'En cours',
      'paid' => 'Payé',
      'failed' => 'Échoué',
      _ => value,
    };
  }

  bool get canCancel =>
      parsedStatus == ReservationStatus.pending &&
      const {'unpaid', 'failed'}.contains(paymentStatus);

  bool get canPay =>
      parsedStatus == ReservationStatus.pending &&
      const {'unpaid', 'failed', 'pending'}.contains(paymentStatus);

  bool get canRequestQr =>
      paymentStatus == 'paid' &&
      (parsedStatus == ReservationStatus.pending ||
          parsedStatus == ReservationStatus.confirmed);

  String? get createdAtLabel {
    final date = createdAt?.toLocal();
    if (date == null) return null;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
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

  static DateTime? parseCreatedAt(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is Map<String, dynamic>) {
      final seconds = _intValue(value['_seconds'] ?? value['seconds']);
      final nanoseconds = _intValue(
        value['_nanoseconds'] ?? value['nanoseconds'],
      );
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds ?? 0) ~/ 1000000,
          isUtc: true,
        );
      }
    }
    return null;
  }
}
