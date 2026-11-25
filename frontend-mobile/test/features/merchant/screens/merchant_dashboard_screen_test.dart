import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/merchant/data/demo_merchant_repository.dart';
import 'package:myfirstflutterp/features/merchant/data/merchant_api_repository.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_offer.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_order.dart';
import 'package:myfirstflutterp/features/merchant/screens/create_offer_screen.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_dashboard_screen.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_offers_screen.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_shop_screen.dart';

class _TokenStore implements AuthTokenStore {
  @override
  Future<String?> read(String key) async =>
      key == 'campussave_id_token' ? 'test-token' : null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

http.Response _response(Object data, [int status = 200]) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _shop = {
  'shopId': 'shop-1',
  'name': 'Le marché',
  'address': 'Tunis',
  'phone': '12345678',
  'status': 'approved',
};
const _dashboard = {
  'offers': {'total': 8, 'listed': 3},
  'reservations': {'total': 12},
  'revenue': {
    'paid': {
      'total': 52.125,
      'byMode': {'mock': 10, 'sandbox': 42.125},
    },
  },
  'itemsSold': 6,
  'topOffers': [
    {
      'offerName': 'Panier préféré',
      'reservations': 4,
      'quantityReserved': 7,
      'paidRevenue': 24.125,
    },
  ],
  'recentReservations': [
    {
      'reservationId': 'recent-1',
      'offerId': 'offer-1',
      'offerName': 'Repas récent',
      'quantity': 2,
      'totalPrice': 12.125,
      'status': 'completed',
      'paymentStatus': 'paid',
      'createdAt': '2026-11-20T15:00:00.000Z',
    },
  ],
};
const _listedOffer = {
  'id': 'offer-1',
  'title': 'Panier frais',
  'category': 'Paniers',
  'originalPrice': 12,
  'discountedPrice': 5,
  'quantity': 8,
  'availableQuantity': 3,
  'pickupStart': '12:00',
  'pickupEnd': '14:00',
  'status': 'active',
};

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
    'approved shop loads real offers and edits without resending stock',
    (tester) async {
      var offer = _listedOffer;
      var listCalls = 0;
      var dashboardCalls = 0;
      final auth = AuthRepository(
        tokenStore: _TokenStore(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          switch ((request.method, request.url.path)) {
            case ('GET', '/api/shops/my-shop'):
              return _response(_shop);
            case ('GET', '/api/dashboard/merchant'):
              dashboardCalls++;
              return _response(_dashboard);
            case ('GET', '/api/offers/merchant/my-offers'):
              listCalls++;
              return _response([offer]);
            case ('PUT', '/api/offers/offer-1'):
              expect(jsonDecode(request.body), {'name': 'Panier du soir'});
              offer = {...offer, 'name': 'Panier du soir'};
              return _response(offer);
            default:
              fail('Appel inattendu ${request.method} ${request.url.path}');
          }
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MerchantDashboardScreen(authRepository: auth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('merchant-open-offers')));
      await tester.pumpAndSettle();

      expect(find.byType(MerchantOffersScreen), findsOneWidget);
      expect(find.text('Panier frais'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('merchant-edit-offer-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('merchant-offer-name')),
        'Panier du soir',
      );
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Panier du soir'), findsOneWidget);
      expect(listCalls, 2);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(dashboardCalls, 2);
    },
  );

  testWidgets('registers a missing shop, edits it and waits for approval', (
    tester,
  ) async {
    final auth = AuthRepository(
      tokenStore: _TokenStore(),
      client: MockClient((request) async {
        switch ((request.method, request.url.path)) {
          case ('GET', '/api/shops/my-shop'):
            return http.Response(
              '{"success":false,"message":"You have not registered a shop yet."}',
              404,
            );
          case ('POST', '/api/shops/register'):
            expect(jsonDecode(request.body), {
              'name': 'Le marché',
              'address': 'Tunis',
              'phone': '12345678',
              'description': '',
            });
            return _response({..._shop, 'status': 'pending'}, 201);
          case ('PUT', '/api/shops/my-shop'):
            expect(jsonDecode(request.body)['address'], 'La Marsa');
            return _response({
              ..._shop,
              'status': 'pending',
              'address': 'La Marsa',
            });
          default:
            fail('Appel inattendu ${request.method} ${request.url.path}');
        }
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MerchantDashboardScreen(authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inscrire mon commerce'));
    await tester.pumpAndSettle();
    expect(find.byType(MerchantShopScreen), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Le marché');
    await tester.enterText(fields.at(1), 'Tunis');
    await tester.enterText(fields.at(2), '12345678');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('En attente de validation'), findsOneWidget);
    expect(find.byKey(const ValueKey('merchant-open-offers')), findsNothing);
    await tester.tap(find.text('Modifier le commerce'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), 'La Marsa');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('La Marsa'), findsOneWidget);
  });

  testWidgets('offer creation validates prices and posts canonical fields', (
    tester,
  ) async {
    var posts = 0;
    final auth = AuthRepository(
      tokenStore: _TokenStore(),
      client: MockClient((request) async {
        if (request.url.path == '/api/shops/my-shop') return _response(_shop);
        if (request.url.path == '/api/dashboard/merchant') {
          return _response(_dashboard);
        }
        posts++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/offers');
        expect(jsonDecode(request.body), {
          'name': 'Repas du jour',
          'description': '',
          'category': 'Paniers',
          'originalPrice': 10,
          'discountPrice': 5.5,
          'quantity': 4,
          'pickupStart': '12:00',
          'pickupEnd': '14:00',
          'imageURL': '',
        });
        return _response({
          ..._listedOffer,
          'id': null,
          'offerId': 'created-1',
          'name': 'Repas du jour',
        }, 201);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MerchantDashboardScreen(authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('merchant-create-offer')));
    await tester.pumpAndSettle();

    Future<void> fill(String field, String value) async {
      final finder = find.byKey(ValueKey('merchant-offer-$field'));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
    }

    Future<void> save() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Enregistrer')),
        alignment: 0.8,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
    }

    await fill('name', 'Repas du jour');
    await fill('originalPrice', '10');
    await fill('discountPrice', '10');
    await fill('quantity', '4');
    await fill('pickupStart', '12:00');
    await fill('pickupEnd', '14:00');
    await save();
    expect(posts, 0);
    expect(
      find.text('Le prix réduit doit être inférieur au prix initial.'),
      findsOneWidget,
    );
    await fill('discountPrice', '5,5');
    await save();
    expect(posts, 1);
    expect(find.byType(CreateOfferScreen), findsNothing);
  });

  test('an unrelated 404 does not look like a missing shop', () async {
    final api = MerchantApiRepository(
      AuthRepository(
        tokenStore: _TokenStore(),
        client: MockClient(
          (_) async =>
              http.Response('{"message":"User profile not found."}', 404),
        ),
      ),
    );
    await expectLater(
      api.getShop(),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('rejects malformed offer collection data', () async {
    final api = MerchantApiRepository(
      AuthRepository(
        tokenStore: _TokenStore(),
        client: MockClient(
          (_) async => _response([
            {'name': 'Sans identifiant'},
          ]),
        ),
      ),
    );
    await expectLater(api.getOffers(), throwsA(isA<AuthException>()));
  });

  testWidgets(
    'approved merchant sees authoritative statistics and recent reservations',
    (tester) async {
      final auth = AuthRepository(
        tokenStore: _TokenStore(),
        client: MockClient((request) async {
          switch ((request.method, request.url.path)) {
            case ('GET', '/api/shops/my-shop'):
              return _response(_shop);
            case ('GET', '/api/dashboard/merchant'):
              expect(request.headers['Authorization'], 'Bearer test-token');
              return _response(_dashboard);
            default:
              fail('Appel inattendu ${request.method} ${request.url.path}');
          }
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MerchantDashboardScreen(authRepository: auth),
        ),
      );
      await tester.pumpAndSettle();
      for (final (key, value) in [
        ('merchant-stat-offers', '8'),
        ('merchant-stat-orders', '12'),
        ('merchant-stat-revenue', '52.125 DT'),
        ('merchant-stat-items-sold', '6'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text(value),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Mock · 10.000 DT'), findsOneWidget);
      expect(find.text('Sandbox · 42.125 DT'), findsOneWidget);
      expect(find.text('Panier préféré'), findsOneWidget);
      expect(find.text('Repas récent'), findsOneWidget);
      expect(find.text('Payé'), findsOneWidget);
      expect(find.text('1 / 12'), findsOneWidget);
      expect(find.text('Client confirmed'), findsNothing);
    },
  );
}
