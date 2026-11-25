import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/home/screens/home_screen.dart';
import 'package:myfirstflutterp/features/search/data/shop_repository.dart';
import 'package:myfirstflutterp/features/search/models/shop_offer.dart';
import 'package:myfirstflutterp/features/search/screens/search_screen.dart';

class _MemoryTokenStore implements AuthTokenStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

const _offerJson = <String, dynamic>{
  'id': 'api-offer-1',
  'name': 'Offre API',
  'description': 'Description from backend.',
  'category': 'Paniers',
  'originalPrice': 8,
  'discountPrice': 4.5,
  'quantity': 8,
  'availableQuantity': 3,
  'imageURL': null,
  'pickupStart': '12:00',
  'pickupEnd': '14:00',
  'shopId': 'api-shop-1',
  'shopName': null,
  'status': 'available',
  'isExpired': false,
  'isSoldOut': false,
};

const _offersResponse =
    '{"success":true,"count":1,"data":[{"id":"api-offer-1","name":"Offre API","description":"Description from backend.","category":"Paniers","originalPrice":8,"discountPrice":4.5,"quantity":8,"availableQuantity":3,"imageURL":null,"pickupStart":"12:00","pickupEnd":"14:00","shopId":"api-shop-1","shopName":null,"status":"available","isExpired":false,"isSoldOut":false}]}';

ShopRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ShopRepository(
    authRepository: AuthRepository(
      client: MockClient(handler),
      tokenStore: _MemoryTokenStore(),
    ),
  );
}

void main() {
  test('a dated pickup expires even when the server flags are stale', () {
    final offer = ShopOffer.fromJson({
      'id': 'expired',
      'name': 'Offre expirée',
      'status': 'available',
      'availableQuantity': 2,
      'pickupEnd': '2000-01-01T14:00:00Z',
      'isExpired': false,
    });
    expect(offer.pickupExpired, isTrue);
    expect(offer.isUnavailable, isTrue);
    const recurring = ShopOffer(
      id: 'recurring',
      name: 'Créneau récurrent',
      status: 'available',
      pickupEnd: '00:15',
    );
    expect(recurring.isUnavailable, isFalse);
  });

  test('maps backend fields and optional offer values', () async {
    final repository = _repository(
      (_) async => http.Response(_offersResponse, 200),
    );

    final offer = (await repository.fetchOffers()).single;

    expect(offer.id, 'api-offer-1');
    expect(offer.name, 'Offre API');
    expect(offer.originalPrice, 8);
    expect(offer.discountPrice, 4.5);
    expect(offer.quantity, 8);
    expect(offer.availableQuantity, 3);
    expect(offer.imageUrl, isNull);
    expect(offer.shopName, isNull);
  });

  test('sends supported category, price, and search filters', () async {
    late Uri requestUri;
    final repository = _repository((request) async {
      requestUri = request.url;
      return http.Response('{"success":true,"count":0,"data":[]}', 200);
    });

    await repository.fetchOffers(
      category: 'Paniers',
      maxPrice: 5,
      query: 'anti-gaspi',
    );

    expect(requestUri.path, '/api/offers');
    expect(requestUri.queryParameters, {
      'category': 'Paniers',
      'maxPrice': '5.0',
      'q': 'anti-gaspi',
    });
  });

  test('fetches offer details using the API ID', () async {
    late Uri requestUri;
    final repository = _repository((request) async {
      requestUri = request.url;
      return http.Response(
        '{"success":true,"data":{"id":"api-offer-1","name":"Offre API"}}',
        200,
      );
    });

    final offer = await repository.fetchOfferById('api-offer-1');

    expect(requestUri.path, '/api/offers/api-offer-1');
    expect(offer.id, 'api-offer-1');
  });

  test('returns an empty list and surfaces retryable server errors', () async {
    final emptyRepository = _repository(
      (_) async => http.Response('{"success":true,"count":0,"data":[]}', 200),
    );
    expect(await emptyRepository.fetchOffers(), isEmpty);

    final failedRepository = _repository(
      (_) async => http.Response('{"success":false}', 500),
    );
    await expectLater(
      failedRepository.fetchOffers(),
      throwsA(
        isA<ShopRepositoryException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  testWidgets('search shows only returned offers, without demo shops', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requestedPaths = <String>[];
    final repository = _repository((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/api/offers') {
        return http.Response(_offersResponse, 200);
      }
      if (request.url.path == '/api/offers/api-offer-1') {
        return http.Response(
          '{"success":true,"data":{"id":"api-offer-1","name":"Offre API","description":"Description from backend.","category":"Paniers","originalPrice":8,"discountPrice":4.5,"quantity":8,"availableQuantity":3,"imageURL":null,"pickupStart":"12:00","pickupEnd":"14:00","shopId":"api-shop-1","shopName":null,"status":"available","isExpired":false,"isSoldOut":false}}',
          200,
        );
      }
      return http.Response('{"success":false,"message":"Not found"}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SearchScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Offre API'), findsOneWidget);
    expect(find.text('Snack Campus'), findsNothing);
    expect(find.text('Cafétéria ESSECT'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
    expect(requestedPaths, contains('/api/offers'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home loads an API offer and retries an empty response', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var requestCount = 0;
    final repository = _repository((_) async {
      requestCount++;
      return http.Response(
        requestCount == 1
            ? '{"success":true,"count":0,"data":[]}'
            : _offersResponse,
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Aucune offre disponible pour le moment.'),
      findsOneWidget,
    );
    final retry = find.byKey(const ValueKey('home-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Offre API'), findsWidgets);
    expect(requestCount, 2);
    expect(tester.takeException(), isNull);
  });

  test('an unavailable API offer is not considered bookable', () {
    final offer = ShopOffer.fromJson({
      ..._offerJson,
      'availableQuantity': 0,
      'isSoldOut': true,
    });

    expect(offer.isUnavailable, isTrue);
  });
}
