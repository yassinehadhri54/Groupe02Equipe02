import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/admin/data/admin_api_repository.dart';
import 'package:myfirstflutterp/features/admin/models/admin_data.dart';
import 'package:myfirstflutterp/features/admin/screens/admin_dashboard_screen.dart';
import 'package:myfirstflutterp/features/auth/screens/account_status_screen.dart';
import 'package:myfirstflutterp/features/auth/screens/login_screen.dart';
import 'package:myfirstflutterp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _admin = AuthUser(
  uid: 'admin-1',
  email: 'admin@example.test',
  fullName: 'Compte de test',
  role: 'admin',
  status: 'active',
);

const _dashboard = {
  'users': {'total': 19},
  'shops': {
    'total': 8,
    'byStatus': {'pending': 3},
  },
  'offers': {'total': 12},
  'reservations': {'total': 24},
};

const _student = {
  'uid': 'user-1',
  'fullName': 'Sami Étudiant',
  'email': 'sami@example.test',
  'role': 'student',
  'status': 'active',
};

const _shop = {
  'id': 'shop-1',
  'name': 'Boulangerie centrale',
  'address': 'Tunis',
  'ownerName': 'Propriétaire test',
  'status': 'pending',
};

class _Tokens implements AuthTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

http.Response _json(Map<String, Object?> data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _data(Object data) => _json({'success': true, 'data': data});

Map<String, String> _account({
  String role = 'admin',
  String status = 'active',
}) => {
  'uid': _admin.uid,
  'email': _admin.email,
  'fullName': _admin.fullName,
  'role': role,
  'status': status,
};

http.Response _authenticated({
  String role = 'admin',
  String status = 'active',
}) => _json({
  'success': true,
  'user': _account(role: role, status: status),
  'tokens': {'idToken': 'test-id', 'refreshToken': 'test-refresh'},
});

AuthRepository _auth(
  Future<http.Response> Function(http.Request) routes,
  _Tokens tokens,
) => AuthRepository(client: MockClient(routes), tokenStore: tokens);

Future<void> _showDashboard(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) routes, {
  _Tokens? tokens,
  bool settle = true,
}) async {
  final store = tokens ?? _Tokens();
  final auth = _auth(routes, store);
  await auth.saveSession(
    const AuthSession(
      user: _admin,
      idToken: 'test-id',
      refreshToken: 'test-refresh',
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AdminDashboardScreen(authRepository: auth, administrator: _admin),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('admin-tab-$index')));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, AuthRepository auth) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: LoginScreen(authRepository: auth),
    ),
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-email')),
    'admin@example.test',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'mot-de-passe-test',
  );
  final button = find.byKey(const ValueKey('login-submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

const _confirm = ValueKey('admin-confirm-decision');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'login uses admin from the server and logout clears the local session',
    (tester) async {
      final tokens = _Tokens();
      final auth = _auth((request) async {
        if (request.url.path == '/api/auth/login') {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'email': 'admin@example.test',
            'password': 'mot-de-passe-test',
          });
          return _authenticated();
        }
        expect(request.url.path, '/api/dashboard/admin');
        expect(request.headers['Authorization'], 'Bearer test-id');
        return _data(_dashboard);
      }, tokens);
      await _login(tester, auth);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(tokens.values, isNotEmpty);
      await _tab(tester, 4);
      expect(find.text('Compte de test'), findsOneWidget);
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tokens.values, isEmpty);
    },
  );

  testWidgets('restores an admin only after the authenticated me response', (
    tester,
  ) async {
    final calls = <String>[];
    final auth = _auth((request) async {
      calls.add(request.url.path);
      expect(request.headers['Authorization'], 'Bearer test-id');
      if (request.url.path == '/api/auth/me') {
        return _json({'success': true, 'user': _account()});
      }
      return _data(_dashboard);
    }, _Tokens());
    await auth.saveSession(
      const AuthSession(
        user: AuthUser(
          uid: 'admin-1',
          email: 'admin@example.test',
          fullName: 'Ancien profil',
          role: 'student',
          status: 'active',
        ),
        idToken: 'test-id',
        refreshToken: 'test-refresh',
      ),
    );
    await tester.pumpWidget(CampusSaveApp(authRepository: auth));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(calls, ['/api/auth/me', '/api/dashboard/admin']);
  });

  for (final (role, status) in [
    ('admin', 'suspended'),
    ('admin', 'disabled'),
    ('unknown', 'active'),
  ]) {
    testWidgets('rejects $role with status $status at login', (tester) async {
      final auth = _auth((request) async {
        expect(request.url.path, '/api/auth/login');
        return _authenticated(role: role, status: status);
      }, _Tokens());
      await _login(tester, auth);
      expect(find.byType(AccountStatusScreen), findsOneWidget);
      expect(find.text('Accès refusé'), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
    });
  }

  for (final code in [401, 403]) {
    testWidgets('handles denied login HTTP $code', (tester) async {
      final tokens = _Tokens();
      final auth = _auth((_) async => _json({'success': false}, code), tokens);
      await _login(tester, auth);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.textContaining(
          code == 401 ? 'mot de passe incorrect' : 'compte est désactivé',
        ),
        findsOneWidget,
      );
      expect(tokens.values, isEmpty);
    });

    testWidgets(
      'dashboard displays HTTP $code and provides a return to login',
      (tester) async {
        final tokens = _Tokens();
        await _showDashboard(
          tester,
          (_) async => _json({'success': false}, code),
          tokens: tokens,
        );
        expect(
          find.textContaining(
            code == 401 ? 'session a expiré' : 'pas les droits',
          ),
          findsOneWidget,
        );
        expect(tokens.values.isEmpty, code == 401);
        await tester.tap(find.text('Retour à la connexion'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tokens.values, isEmpty);
      },
    );
  }

  testWidgets(
    'restoration denies access when the server marks the admin suspended',
    (tester) async {
      final auth = _auth((request) async {
        expect(request.url.path, '/api/auth/me');
        return _json({'success': true, 'user': _account(status: 'suspended')});
      }, _Tokens());
      await auth.saveSession(
        const AuthSession(
          user: _admin,
          idToken: 'test-id',
          refreshToken: 'test-refresh',
        ),
      );
      await tester.pumpWidget(CampusSaveApp(authRepository: auth));
      await tester.pumpAndSettle();
      expect(find.byType(AccountStatusScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
    },
  );

  testWidgets('admin navigation and user filters fit a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    await _showDashboard(tester, (request) async {
      requests.add(request.url.path);
      return request.url.path == '/api/users'
          ? _json({
              'success': true,
              'users': [_account(), _student],
            })
          : _data(_dashboard);
    });
    expect(find.byType(NavigationBar), findsOneWidget);
    await _tab(tester, 2);
    final filters = find.byType(DropdownButton<String>);
    await tester.tap(filters.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Étudiant').last);
    await tester.pumpAndSettle();
    expect(find.text('Sami Étudiant'), findsOneWidget);
    expect(find.text('Compte de test'), findsNothing);
    await tester.tap(filters.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspendu').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun utilisateur pour cette recherche.'),
      findsOneWidget,
    );
    expect(requests, ['/api/dashboard/admin', '/api/users']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard shows loading, real statistics and refreshes to empty',
    (tester) async {
      final result = Completer<http.Response>();
      var requests = 0;
      await _showDashboard(tester, (_) {
        requests++;
        return requests == 1 ? result.future : Future.value(_data({}));
      }, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      result.complete(_data(_dashboard));
      await tester.pumpAndSettle();
      for (final total in ['19', '8', '3', '12', '24']) {
        expect(find.text(total), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Actualiser les statistiques'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune statistique disponible.'), findsOneWidget);
    },
  );

  testWidgets('dashboard shows a server error and supports retry', (
    tester,
  ) async {
    var requests = 0;
    await _showDashboard(tester, (_) async {
      if (++requests == 1) return _json({'success': false}, 500);
      return _data(_dashboard);
    });
    expect(
      find.textContaining('Le serveur rencontre un problème'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Commerces en attente'), findsOneWidget);
  });

  testWidgets(
    'shops filter by backend status and approve and reject after confirmation',
    (tester) async {
      var status = 'pending';
      final calls = <String>[];
      final writes = <String>[];
      await _showDashboard(tester, (request) async {
        final path = request.url.path;
        if (path == '/api/dashboard/admin') return _data(_dashboard);
        if (path == '/api/shops') {
          final filter = request.url.queryParameters['status'];
          calls.add(filter ?? 'all');
          return _data(
            filter == null || filter == status
                ? [
                    {..._shop, 'status': status},
                  ]
                : [],
          );
        }
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer test-id');
        expect(jsonDecode(request.body), isEmpty);
        writes.add(path);
        status = path.endsWith('/approve') ? 'approved' : 'rejected';
        return _data({'shopId': 'shop-1', 'status': status});
      });
      await _tab(tester, 1);
      expect(find.text('Boulangerie centrale'), findsOneWidget);
      final filter = find.descendant(
        of: find.byKey(const ValueKey('admin-shop-filter')),
        matching: find.byType(DropdownButton<String>),
      );
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('En attente').last);
      await tester.pumpAndSettle();
      expect(calls, ['all', 'pending']);
      await tester.tap(find.text('Boulangerie centrale'));
      await tester.pumpAndSettle();
      expect(find.text('Propriétaire test'), findsOneWidget);
      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, ['/api/shops/shop-1/approve']);
      expect(calls.last, 'pending');
      expect(find.text('Aucun commerce pour ce filtre.'), findsOneWidget);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approuvé').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boulangerie centrale'));
      await tester.pumpAndSettle();
      expect(find.text('Approuver'), findsNothing);
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes.last, '/api/shops/shop-1/reject');
      expect(calls.last, 'approved');
    },
  );

  testWidgets('users search locally, load details, suspend and reactivate', (
    tester,
  ) async {
    var status = 'active';
    var details = 0;
    final writes = <String>[];
    await _showDashboard(tester, (request) async {
      final path = request.url.path;
      final user = {..._student, 'status': status};
      switch (path) {
        case '/api/dashboard/admin':
          return _data(_dashboard);
        case '/api/users':
          return _json({
            'success': true,
            'users': [user, _account()],
          });
        case '/api/users/user-1':
          details++;
          return _json({'success': true, 'user': user});
        case '/api/users/user-1/status':
          expect(request.method, 'PUT');
          status = jsonDecode(request.body)['status'] as String;
          writes.add(status);
          return _json({
            'success': true,
            'user': {...user, 'status': status},
          });
        default:
          fail('Unknown mocked path $path');
      }
    });
    await _tab(tester, 2);
    expect(find.text('Compte de test'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('admin-user-search')),
      'SAMI',
    );
    await tester.pumpAndSettle();
    expect(find.text('Compte de test'), findsNothing);
    for (final action in ['Suspendre', 'Réactiver']) {
      await tester.tap(find.text('Sami Étudiant'));
      await tester.pumpAndSettle();
      expect(find.text('sami@example.test'), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(writes.length, details - 1);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
    }
    expect(details, 2);
    expect(writes, ['suspended', 'active']);
  });

  testWidgets(
    'a rejected mutation remains on the details screen and explains the conflict',
    (tester) async {
      await _showDashboard(
        tester,
        (request) async => switch (request.url.path) {
          '/api/dashboard/admin' => _data(_dashboard),
          '/api/shops' => _data([_shop]),
          _ => _json({
            'success': false,
            'message': 'Shop is already approved.',
          }, 409),
        },
      );
      await _tab(tester, 1);
      await tester.tap(find.text('Boulangerie centrale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.textContaining('Le statut a changé'), findsOneWidget);
      expect(find.text('Propriétaire test'), findsOneWidget);
    },
  );

  test(
    'client refuses self-management and administration of other admins',
    () async {
      final repository = AdminApiRepository(
        _auth((_) async => fail('No HTTP request expected'), _Tokens()),
        administratorId: _admin.uid,
      );
      for (final user in [
        AdminUser.fromJson({..._student, 'uid': _admin.uid}),
        AdminUser.fromJson({..._student, 'role': 'admin'}),
      ]) {
        await expectLater(
          repository.updateUser(user, AdminUserAction.suspend),
          throwsA(
            isA<AuthException>().having(
              (error) => error.statusCode,
              'status',
              400,
            ),
          ),
        );
      }
    },
  );

  test(
    'user endpoints preserve forbidden, not found and conflict responses',
    () async {
      final tokens = _Tokens()..values['campussave_id_token'] = 'test-id';
      for (final code in [403, 404, 409]) {
        final api = AdminApiRepository(
          _auth((_) async => _json({'success': false}, code), tokens),
          administratorId: _admin.uid,
        );
        await expectLater(
          api.loadUser('user-1'),
          throwsA(
            isA<AuthException>().having(
              (error) => error.statusCode,
              'status',
              code,
            ),
          ),
        );
        await expectLater(
          api.updateUser(AdminUser.fromJson(_student), AdminUserAction.suspend),
          throwsA(
            isA<AuthException>().having(
              (error) => error.statusCode,
              'status',
              code,
            ),
          ),
        );
      }
    },
  );

  testWidgets(
    'offers tab searches, reads shop details and moderates only after confirmation',
    (tester) async {
      final offer = {
        'id': 'offer-1',
        'name': 'Panier du jour',
        'description': 'Détails du panier',
      };
      final paths = <String>[];
      final writes = <bool>[];
      var disabled = false;
      await _showDashboard(tester, (request) async {
        expect(request.headers['Authorization'], 'Bearer test-id');
        paths.add(request.url.path);
        final current = {
          ...offer,
          'status': 'active',
          'adminDisabled': disabled,
        };
        return switch (request.url.path) {
          '/api/dashboard/admin' => _data(_dashboard),
          '/api/admin/offers' => _data([current]),
          '/api/admin/offers/offer-1' => _data({
            'offer': current,
            'shop': {
              'id': 'shop-1',
              'name': 'Commerce associé',
              'status': 'approved',
            },
          }),
          '/api/admin/offers/offer-1/moderation' => (() {
            expect(request.method, 'PUT');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            disabled = body['adminDisabled'] as bool;
            if (disabled) expect(body['reason'], 'À contrôler');
            writes.add(disabled);
            return _data({'id': 'offer-1', 'adminDisabled': disabled});
          })(),
          _ => fail('Unknown mocked path ${request.url.path}'),
        };
      });
      await _tab(tester, 3);
      await tester.enterText(
        find.byKey(const ValueKey('admin-offer-search')),
        ' Panier ',
      );
      await tester.tap(find.byTooltip('Rechercher et actualiser les offres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panier du jour'));
      await tester.pumpAndSettle();
      expect(find.text('Détails du panier'), findsOneWidget);
      expect(find.text('Commerce associé'), findsOneWidget);
      final reason = find.byKey(const ValueKey('admin-offer-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(reason, ' À contrôler ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final disable = find.text('Désactiver');
      await tester.ensureVisible(disable);
      await tester.tap(disable);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.ensureVisible(disable);
      await tester.tap(disable);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, [true]);
      expect(
        find.textContaining('Désactivée par l’administration'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panier du jour'));
      await tester.pumpAndSettle();
      final enable = find.text('Réactiver');
      await Scrollable.ensureVisible(tester.element(enable), alignment: 0.7);
      await tester.pumpAndSettle();
      await tester.tap(enable);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(writes, [true, false]);
      expect(paths.last, '/api/admin/offers');
      expect(paths.where((path) => path == '/api/admin/offers').length, 4);
    },
  );

  test('offers repository encodes filters and preserves HTTP errors', () async {
    final tokens = _Tokens()..values['campussave_id_token'] = 'test-id';
    final api = AdminApiRepository(
      _auth((request) async {
        return switch (request.url.path) {
          '/api/admin/offers' => (() {
            expect(request.url.queryParameters, {
              'q': 'Pâtés & café',
              'category': 'Repas',
              'status': 'active',
              'adminDisabled': 'false',
            });
            return _data([
              {'id': 'legacy', 'offerId': 'old-id', 'name': 'Un panier'},
            ]);
          })(),
          '/api/admin/offers/missing' => _json({'success': false}, 404),
          '/api/admin/offers/legacy/moderation' => _json({
            'success': false,
          }, 500),
          _ => fail('Unexpected path ${request.url.path}'),
        };
      }, tokens),
      administratorId: _admin.uid,
    );
    final offers = await api.loadOffers(
      query: ' Pâtés & café ',
      category: 'Repas',
      status: 'active',
      adminDisabled: false,
    );
    expect(offers.single.id, 'legacy');
    expect(offers.single.adminDisabled, isFalse);
    await expectLater(
      api.loadOffer('missing'),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 404)),
    );
    await expectLater(
      api.moderateOffer('legacy', adminDisabled: true),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 500)),
    );
  });
}
