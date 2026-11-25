class MerchantShop {
  const MerchantShop({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.status,
    this.email = '',
    this.description = '',
    this.latitude,
    this.longitude,
  });

  factory MerchantShop.fromJson(Map<String, dynamic> json) {
    final id = json['shopId'] ?? json['id'];
    final status = json['status'];
    if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
      throw const FormatException('Commerce sans identifiant ou statut.');
    }

    String text(String field) {
      final value = json[field];
      return value is String ? value : '';
    }

    return MerchantShop(
      id: id,
      name: text('name'),
      address: text('address'),
      phone: text('phone'),
      email: text('email'),
      description: text('description'),
      status: status,
      latitude: _coordinate(json['latitude'], 90),
      longitude: _coordinate(json['longitude'], 180),
    );
  }

  static double? _coordinate(Object? value, double limit) {
    final number = value is num ? value.toDouble() : null;
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String description;
  final String status;
  final double? latitude;
  final double? longitude;
}
