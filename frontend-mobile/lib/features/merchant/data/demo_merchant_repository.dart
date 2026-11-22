import 'package:flutter/foundation.dart';

import '../models/merchant_offer.dart';
import '../models/merchant_order.dart';

abstract interface class MerchantRepository implements Listenable {
  List<MerchantOffer> get offers;
  List<MerchantOrder> get orders;
  MerchantDashboardStats get statistics;

  Future<void> addOffer(MerchantOffer offer);
  Future<void> updateOffer(MerchantOffer offer);
  Future<void> deactivateOffer(String offerId);
}

class MerchantDashboardStats {
  const MerchantDashboardStats({
    required this.activeOfferCount,
    required this.orderCount,
    required this.revenue,
  });

  final int activeOfferCount;
  final int orderCount;
  final double revenue;
}

class DemoMerchantRepository extends ChangeNotifier
    implements MerchantRepository {
  static final DemoMerchantRepository shared = DemoMerchantRepository();

  DemoMerchantRepository({
    List<MerchantOffer>? offers,
    List<MerchantOrder>? orders,
  }) : _offers = List.of(offers ?? _demoOffers()),
       _orders = List.of(orders ?? _demoOrders());

  final List<MerchantOffer> _offers;
  final List<MerchantOrder> _orders;

  @override
  List<MerchantOffer> get offers => List.unmodifiable(_offers);

  @override
  List<MerchantOrder> get orders => List.unmodifiable(_orders);

  @override
  MerchantDashboardStats get statistics {
    final activeOfferCount = _offers.where((offer) => offer.isActive).length;
    final revenue = _orders
        .where(
          (order) =>
              order.status == MerchantOrderStatus.confirmed ||
              order.status == MerchantOrderStatus.completed,
        )
        .fold<double>(0, (total, order) => total + order.totalPrice);

    return MerchantDashboardStats(
      activeOfferCount: activeOfferCount,
      orderCount: _orders.length,
      revenue: revenue,
    );
  }

  @override
  Future<void> addOffer(MerchantOffer offer) async {
    if (_offers.any((existing) => existing.id == offer.id)) {
      throw ArgumentError.value(offer.id, 'offer.id', 'must be unique');
    }

    _offers.add(offer);
    notifyListeners();
  }

  @override
  Future<void> updateOffer(MerchantOffer offer) async {
    final index = _offers.indexWhere((existing) => existing.id == offer.id);
    if (index == -1) {
      throw ArgumentError.value(offer.id, 'offer.id', 'does not exist');
    }

    _offers[index] = offer;
    notifyListeners();
  }

  @override
  Future<void> deactivateOffer(String offerId) async {
    final index = _offers.indexWhere((offer) => offer.id == offerId);
    if (index == -1) {
      throw ArgumentError.value(offerId, 'offerId', 'does not exist');
    }

    final offer = _offers[index];
    if (!offer.isActive) return;

    _offers[index] = offer.copyWith(isActive: false);
    notifyListeners();
  }

  static List<MerchantOffer> _demoOffers() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      MerchantOffer(
        id: 'demo-offer-001',
        title: 'Panier déjeuner étudiant',
        description: 'Un repas complet préparé avec les produits du jour.',
        imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900',
        category: 'Paniers',
        originalPrice: 12,
        discountedPrice: 5,
        quantityAvailable: 8,
        pickupStart: today.add(const Duration(hours: 12)),
        pickupEnd: today.add(const Duration(hours: 14)),
        isActive: true,
        createdAt: today.subtract(const Duration(days: 2)),
      ),
      MerchantOffer(
        id: 'demo-offer-002',
        title: 'Sandwich poulet grillé',
        description: 'Sandwich frais au poulet, salade et sauce maison.',
        imageUrl:
            'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=900',
        category: 'Sandwichs',
        originalPrice: 7,
        discountedPrice: 3.5,
        quantityAvailable: 5,
        pickupStart: today.add(const Duration(hours: 17)),
        pickupEnd: today.add(const Duration(hours: 19)),
        isActive: true,
        createdAt: today.subtract(const Duration(days: 1)),
      ),
      MerchantOffer(
        id: 'demo-offer-003',
        title: 'Assortiment de pâtisseries',
        description: 'Sélection de pâtisseries artisanales de fin de journée.',
        imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=900',
        category: 'Pâtisseries',
        originalPrice: 9,
        discountedPrice: 4,
        quantityAvailable: 0,
        pickupStart: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 16)),
        pickupEnd: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 18)),
        isActive: false,
        createdAt: today.subtract(const Duration(days: 3)),
      ),
    ];
  }

  static List<MerchantOrder> _demoOrders() {
    final now = DateTime.now();

    return [
      MerchantOrder(
        id: 'demo-order-001',
        offerId: 'demo-offer-001',
        offerTitle: 'Panier déjeuner étudiant',
        customerName: 'Amira B.',
        quantity: 1,
        totalPrice: 5,
        pickupDateTime: now.add(const Duration(hours: 1)),
        status: MerchantOrderStatus.pending,
      ),
      MerchantOrder(
        id: 'demo-order-002',
        offerId: 'demo-offer-002',
        offerTitle: 'Sandwich poulet grillé',
        customerName: 'Youssef K.',
        quantity: 2,
        totalPrice: 7,
        pickupDateTime: now.add(const Duration(hours: 4)),
        status: MerchantOrderStatus.confirmed,
      ),
      MerchantOrder(
        id: 'demo-order-003',
        offerId: 'demo-offer-001',
        offerTitle: 'Panier déjeuner étudiant',
        customerName: 'Sarra M.',
        quantity: 1,
        totalPrice: 5,
        pickupDateTime: now.subtract(const Duration(days: 1)),
        status: MerchantOrderStatus.completed,
      ),
      MerchantOrder(
        id: 'demo-order-004',
        offerId: 'demo-offer-002',
        offerTitle: 'Sandwich poulet grillé',
        customerName: 'Ali R.',
        quantity: 1,
        totalPrice: 3.5,
        pickupDateTime: now.subtract(const Duration(hours: 3)),
        status: MerchantOrderStatus.cancelled,
      ),
    ];
  }
}
