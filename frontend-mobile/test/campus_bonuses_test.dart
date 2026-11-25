import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/impact/screens/impact_dashboard_screen.dart';
import 'package:myfirstflutterp/features/profile/models/profile_data.dart';
import 'package:myfirstflutterp/features/radar/screens/campus_radar_screen.dart';
import 'package:myfirstflutterp/features/search/data/shop_repository.dart';
import 'package:myfirstflutterp/features/search/models/shop_offer.dart';

class _TokenStore implements AuthTokenStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

http.Response _json(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy offers stay standard and old profiles start at zero', () {
    expect(
      ShopOffer.fromJson({'id': 'old', 'title': 'Ancienne offre'})
          .isSurpriseBasket,
      false,
    );
    final basket = ShopOffer.fromJson({
      'id': 'basket',
      'name': 'Panier',
      'offerType': 'surprise_basket',
      'allergenInfo': 'Gluten',
      'adminDisabled': true,
    });
    expect(basket.isSurpriseBasket, true);
    expect(basket.allergenInfo, 'Gluten');
    expect(basket.isUnavailable, true);
    expect(ProfileData.fromJson({}).ecoPoints, 0);
  });

  testWidgets('radar asks for location on demand and supports denial', (
    tester,
  ) async {
    var locationRequests = 0;
    final calls = <Uri>[];
    final repository = ShopRepository(
      authRepository: AuthRepository(
        client: MockClient((request) async {
          calls.add(request.url);
          return _json([]);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CampusRadarScreen(
          repository: repository,
          showTiles: false,
          locate: () async {
            locationRequests++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(locationRequests, 0);
    expect(calls, isEmpty);
    await tester.tap(find.text('Ma position'));
    await tester.pumpAndSettle();
    expect(locationRequests, 1);
    expect(find.textContaining('Localisation indisponible'), findsOneWidget);
    await tester.tap(find.text('Rechercher ici'));
    await tester.pumpAndSettle();
    expect(calls.single.path, '/api/shops/nearby');
    expect(calls.single.queryParameters['radius'], '5');
    expect(find.text('Aucun commerce localisé dans ce rayon.'), findsOneWidget);
  });

  testWidgets('radar passes the actual position and radius to the API', (
    tester,
  ) async {
    final calls = <Uri>[];
    final repository = ShopRepository(
      authRepository: AuthRepository(
        client: MockClient((request) async {
          calls.add(request.url);
          return _json([
            {
              'shopId': 'a',
              'name': 'Proche',
              'distanceMeters': 100,
              'latitude': 36.801,
              'longitude': 10.18,
            },
            {
              'shopId': 'b',
              'name': 'Invalide',
              'distanceMeters': 300,
              'latitude': 100,
              'longitude': 10.18,
            },
          ]);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CampusRadarScreen(
          repository: repository,
          showTiles: false,
          locate: () async => const LatLng(36.8, 10.18),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ma position'));
    await tester.pumpAndSettle();
    expect(calls.single.queryParameters['lat'], '36.8');
    expect(find.text('Proche'), findsOneWidget);
    expect(find.text('Invalide'), findsNothing);
    await tester.tap(find.text('3 km'));
    await tester.pumpAndSettle();
    expect(calls.last.queryParameters['radius'], '3');
  });

  for (final scope in ImpactScope.values) {
    testWidgets('impact uses the authenticated route for ${scope.name}', (
      tester,
    ) async {
      final calls = <http.Request>[];
      final repository = AuthRepository(
        tokenStore: _TokenStore(),
        client: MockClient((request) async {
          calls.add(request);
          return _json({
            'impact': {
              'recoveredOrders': 1,
              'portions': 2,
              'savings': 10,
              'participatingShops': 1,
              'weekly': [
                {'start': '2026-11-23', 'portions': 2, 'recoveredOrders': 1},
              ],
              'monthly': [
                {'start': '2026-11-01', 'portions': 2, 'recoveredOrders': 1},
              ],
            },
            'ecoPoints': {
              'total': 20,
              'history': [
                {'reservationId': 'res-1', 'points': 20, 'date': '2026-11-25'},
              ],
            },
          });
        }),
      );
      await repository.saveSession(
        AuthSession(
          user: AuthUser(
            uid: 'test',
            email: 'test@example.test',
            fullName: 'Campus',
            role: scope.name,
            status: 'active',
          ),
          idToken: 'test-id',
          refreshToken: 'test-refresh',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: scope == ImpactScope.student ? AppTheme.light : AppTheme.dark,
          home: ImpactDashboardScreen(repository: repository, scope: scope),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.single.url.path, '/api/dashboard/${scope.name}');
      expect(calls.single.headers['Authorization'], 'Bearer test-id');
      expect(find.text('Portions sauvées'), findsOneWidget);
      expect(
        find.text('Commerces participants'),
        scope == ImpactScope.admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('EcoPoints cumulés'),
        scope == ImpactScope.student ? findsOneWidget : findsNothing,
      );
      expect(find.text('Semaine du 23 novembre 2026'), findsOneWidget);
      await tester.tap(find.text('Mois'));
      await tester.pumpAndSettle();
      expect(find.text('novembre 2026'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mois'))
            .selected,
        true,
      );
    });
  }

  for (final scope in ImpactScope.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'relance ${scope.name} en mode $dark après une erreur réseau',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var calls = 0;
          final recovery = Completer<http.Response>();
          final auth = AuthRepository(
            tokenStore: _TokenStore(),
            client: MockClient((request) async {
              expect(request.url.path, '/api/dashboard/${scope.name}');
              if (calls++ == 0) {
                throw http.ClientException('Réseau indisponible');
              }
              return recovery.future;
            }),
          );
          await auth.saveSession(
            AuthSession(
              user: AuthUser(
                uid: 'qa',
                email: 'qa@example.test',
                fullName: 'QA',
                role: scope.name,
                status: 'active',
              ),
              idToken: 'test-id',
              refreshToken: 'test-refresh',
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: ImpactDashboardScreen(repository: auth, scope: scope),
            ),
          );
          await tester.pumpAndSettle();
          final retry = find.textContaining('Réessayer');
          await tester.tap(retry);
          await tester.tap(retry);
          await tester.pump();
          expect(calls, 2);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(retry, findsNothing);

          recovery.complete(
            _json({
              'impact': {'recoveredOrders': 0, 'portions': 0, 'savings': 0},
            }),
          );
          await tester.pumpAndSettle();
          expect(find.text('Portions sauvées'), findsOneWidget);
          if (scope == ImpactScope.student) {
            expect(find.text('0,000 DT'), findsOneWidget);
          }
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(
            find.text('Aucun retrait validé pour le moment.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(calls, 2);
        },
      );
    }
  }

  for (final offers in [false, true]) {
    testWidgets('relance Radar après erreur: liste des offres = $offers', (
      tester,
    ) async {
      var calls = 0;
      final recovery = Completer<http.Response>();
      final repository = ShopRepository(
        authRepository: AuthRepository(
          client: MockClient((request) async {
            if (offers && request.url.path == '/api/shops/nearby') {
              return _json([
                {
                  'shopId': 'qa',
                  'name': 'Commerce QA',
                  'distanceMeters': 100,
                  'latitude': 36.81,
                  'longitude': 10.1815,
                },
              ]);
            }
            expect(
              request.url.path,
              offers ? '/api/offers' : '/api/shops/nearby',
            );
            if (offers) expect(request.url.queryParameters['shopId'], 'qa');
            if (calls++ == 0) throw http.ClientException('Réseau indisponible');
            return recovery.future;
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: CampusRadarScreen(repository: repository, showTiles: false),
        ),
      );
      await tester.tap(find.text('Rechercher ici'));
      await tester.pumpAndSettle();
      if (offers) {
        await tester.tap(find.text('Commerce QA'));
        await tester.pumpAndSettle();
      }
      final retry = find.textContaining('Réessayer');
      await tester.tap(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      recovery.complete(
        _json(
          offers
              ? [
                  {
                    'id': 'panier',
                    'name': 'Panier QA',
                    'offerType': 'surprise_basket',
                  },
                ]
              : [],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          offers ? 'Panier QA' : 'Aucun commerce localisé dans ce rayon.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('économies indisponibles pour un retrait sans prix initial', (
    tester,
  ) async {
    final auth = AuthRepository(
      tokenStore: _TokenStore(),
      client: MockClient((_) async {
        return _json({
          'impact': {
            'recoveredOrders': 1,
            'portions': 2,
            'savings': 0,
            'missingSavings': 1,
          },
        });
      }),
    );
    await auth.saveSession(
      const AuthSession(
        user: AuthUser(
          uid: 'qa',
          email: 'qa@example.test',
          fullName: 'QA',
          role: 'student',
          status: 'active',
        ),
        idToken: 'test-id',
        refreshToken: 'test-refresh',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImpactDashboardScreen(
          repository: auth,
          scope: ImpactScope.student,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Indisponible'), findsOneWidget);
    expect(find.text('0,000 DT'), findsNothing);
  });
}
