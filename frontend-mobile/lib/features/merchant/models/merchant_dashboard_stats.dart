import 'merchant_order.dart';

class MerchantDashboardStats {
  const MerchantDashboardStats({
    required this.activeOfferCount,
    required this.orderCount,
    required this.revenue,
    this.offerCount,
    this.itemsSold,
    this.revenueByMode = const {},
    this.topOffers = const [],
    this.recentReservations = const [],
  });

  factory MerchantDashboardStats.fromJson(Map<String, dynamic> json) {
    final offers = _object(json['offers']);
    final reservations = _object(json['reservations']);
    final paid = _object(_object(json['revenue'])['paid']);
    return MerchantDashboardStats(
      activeOfferCount: _count(offers['listed']),
      offerCount: _count(offers['total']),
      orderCount: _count(reservations['total']),
      itemsSold: _count(json['itemsSold']),
      revenue: _money(paid['total']),
      revenueByMode: Map.unmodifiable(
        _object(paid['byMode'])
            .map((mode, amount) => MapEntry(mode, _money(amount))),
      ),
      topOffers: List.unmodifiable(
        _list(json['topOffers'])
            .map((entry) => MerchantTopOffer.fromJson(_object(entry))),
      ),
      recentReservations: List.unmodifiable(
        _list(json['recentReservations'])
            .map((entry) => MerchantOrder.fromJson(_object(entry))),
      ),
    );
  }

  final int activeOfferCount;
  final int? offerCount;
  final int orderCount;
  final double revenue;
  final int? itemsSold;
  final Map<String, double> revenueByMode;
  final List<MerchantTopOffer> topOffers;
  final List<MerchantOrder> recentReservations;
}

class MerchantTopOffer {
  const MerchantTopOffer({
    required this.name,
    required this.reservations,
    required this.quantityReserved,
    required this.paidRevenue,
  });

  factory MerchantTopOffer.fromJson(Map<String, dynamic> json) {
    final name = json['offerName'];
    if (name is! String) throw const FormatException();
    return MerchantTopOffer(
      name: name,
      reservations: _count(json['reservations']),
      quantityReserved: _count(json['quantityReserved']),
      paidRevenue: _money(json['paidRevenue']),
    );
  }

  final String name;
  final int reservations;
  final int quantityReserved;
  final double paidRevenue;
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException();
}

List<dynamic> _list(Object? value) {
  if (value is List<dynamic>) return value;
  throw const FormatException();
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  throw const FormatException();
}

double _money(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  throw const FormatException();
}
