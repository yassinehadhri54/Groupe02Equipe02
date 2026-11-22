import 'package:flutter_test/flutter_test.dart';
import 'package:myfirstflutterp/features/merchant/data/demo_merchant_repository.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_offer.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_order.dart';

MerchantOffer _offer({
  String id = 'offer-test',
  String title = 'Panier du jour',
  bool isActive = true,
}) {
  final now = DateTime(2026, 11, 18);
  return MerchantOffer(
    id: id,
    title: title,
    description: 'Repas de démonstration',
    imageUrl: 'https://example.test/offer.jpg',
    category: 'Paniers',
    originalPrice: 12,
    discountedPrice: 5,
    quantityAvailable: 4,
    pickupStart: now.add(const Duration(hours: 2)),
    pickupEnd: now.add(const Duration(hours: 4)),
    isActive: isActive,
    createdAt: now,
  );
}

void main() {
  group('Merchant models', () {
    test('offer stores its fields and copyWith preserves unchanged values', () {
      final offer = _offer();
      final updated = offer.copyWith(title: 'Nouveau panier');

      expect(offer.id, 'offer-test');
      expect(offer.discountedPrice, 5);
      expect(updated.title, 'Nouveau panier');
      expect(updated.id, offer.id);
      expect(updated.isActive, isTrue);
    });

    test('order exposes each supported status', () {
      final order = MerchantOrder(
        id: 'order-test',
        offerId: 'offer-test',
        offerTitle: 'Panier du jour',
        customerName: 'Client test',
        quantity: 2,
        totalPrice: 10,
        pickupDateTime: DateTime(2026, 11, 18, 12),
        status: MerchantOrderStatus.pending,
      );

      expect(order.quantity, 2);
      expect(
        MerchantOrderStatus.values,
        containsAll([
          MerchantOrderStatus.pending,
          MerchantOrderStatus.confirmed,
          MerchantOrderStatus.completed,
          MerchantOrderStatus.cancelled,
        ]),
      );
    });
  });

  group('DemoMerchantRepository', () {
    test('provides demo data and returns unmodifiable collections', () {
      final repository = DemoMerchantRepository();

      expect(repository.offers, isNotEmpty);
      expect(repository.orders, isNotEmpty);
      expect(() => repository.offers.add(_offer()), throwsUnsupportedError);
    });

    test('adds, updates, and deactivates offers with notifications', () async {
      final repository = DemoMerchantRepository(offers: [], orders: []);
      var notifications = 0;
      repository.addListener(() => notifications++);

      await repository.addOffer(_offer());
      expect(repository.offers.single.title, 'Panier du jour');

      await repository.updateOffer(_offer(title: 'Panier modifié'));
      expect(repository.offers.single.title, 'Panier modifié');

      await repository.deactivateOffer('offer-test');
      expect(repository.offers.single.isActive, isFalse);
      expect(notifications, 3);

      repository.dispose();
    });

    test('rejects duplicate and unknown offer identifiers', () async {
      final repository = DemoMerchantRepository(offers: [_offer()], orders: []);

      await expectLater(
        repository.addOffer(_offer()),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.updateOffer(_offer(id: 'missing')),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.deactivateOffer('missing'),
        throwsA(isA<ArgumentError>()),
      );

      repository.dispose();
    });

    test('calculates active offers, all orders, and settled revenue', () {
      final repository = DemoMerchantRepository(
        offers: [
          _offer(),
          _offer(id: 'inactive', isActive: false),
        ],
        orders: [
          _order('pending', 3, MerchantOrderStatus.pending),
          _order('confirmed', 7, MerchantOrderStatus.confirmed),
          _order('completed', 5, MerchantOrderStatus.completed),
          _order('cancelled', 20, MerchantOrderStatus.cancelled),
        ],
      );

      expect(repository.statistics.activeOfferCount, 1);
      expect(repository.statistics.orderCount, 4);
      expect(repository.statistics.revenue, 12);

      repository.dispose();
    });
  });
}

MerchantOrder _order(String id, double price, MerchantOrderStatus status) {
  return MerchantOrder(
    id: id,
    offerId: 'offer-test',
    offerTitle: 'Panier du jour',
    customerName: 'Client test',
    quantity: 1,
    totalPrice: price,
    pickupDateTime: DateTime(2026, 11, 18, 12),
    status: status,
  );
}
