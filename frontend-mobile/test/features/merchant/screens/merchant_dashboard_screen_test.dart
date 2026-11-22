import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/merchant/data/demo_merchant_repository.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_offer.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_order.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_offers_screen.dart';

MerchantOffer _offer(String id, {bool active = true}) {
  final now = DateTime(2026, 11, 18);
  return MerchantOffer(
    id: id,
    title: 'Offre $id',
    description: 'Description',
    imageUrl: 'https://example.test/$id.jpg',
    category: 'Paniers',
    originalPrice: 10,
    discountedPrice: 5,
    quantityAvailable: 4,
    pickupStart: now.add(const Duration(hours: 2)),
    pickupEnd: now.add(const Duration(hours: 4)),
    isActive: active,
    createdAt: now,
  );
}

MerchantOrder _order(
  String id,
  double price,
  MerchantOrderStatus status,
  DateTime pickupDateTime,
) {
  return MerchantOrder(
    id: id,
    offerId: 'offer-1',
    offerTitle: 'Panier frais',
    customerName: 'Client $id',
    quantity: 2,
    totalPrice: price,
    pickupDateTime: pickupDateTime,
    status: status,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('dashboard displays repository-derived statistics and orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = DemoMerchantRepository(
      offers: [_offer('active-1'), _offer('inactive', active: false)],
      orders: [
        _order(
          'pending',
          3,
          MerchantOrderStatus.pending,
          DateTime(2026, 11, 18, 12),
        ),
        _order(
          'confirmed',
          8.25,
          MerchantOrderStatus.confirmed,
          DateTime(2026, 11, 18, 13),
        ),
        _order(
          'cancelled',
          20,
          MerchantOrderStatus.cancelled,
          DateTime(2026, 11, 18, 14),
        ),
      ],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MerchantDashboardScreen(repository: repository),
      ),
    );

    expect(find.text('Espace commerçant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-stat-active-offers')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-stat-orders')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-stat-revenue')),
        matching: find.text('8.250 DT'),
      ),
      findsOneWidget,
    );
    expect(find.text('Client confirmed'), findsOneWidget);
    expect(find.text('Panier frais'), findsWidgets);
    expect(find.text('2 portions'), findsWidgets);
    expect(find.text('Confirmée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows an empty orders state and refreshes on change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = DemoMerchantRepository(
      offers: [_offer('only-offer')],
      orders: [],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MerchantDashboardScreen(repository: repository),
      ),
    );

    expect(find.byKey(const ValueKey('merchant-empty-orders')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-stat-orders')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await repository.addOffer(_offer('second-offer'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-stat-active-offers')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'quick action opens the offers placeholder with same repository',
    (tester) async {
      final repository = DemoMerchantRepository(offers: [], orders: []);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MerchantDashboardScreen(repository: repository),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('merchant-open-offers')));
      await tester.pumpAndSettle();

      final offersScreen = tester.widget<MerchantOffersScreen>(
        find.byType(MerchantOffersScreen),
      );
      expect(offersScreen.repository, same(repository));
      expect(find.text('Offres commerçant'), findsOneWidget);
    },
  );
}
