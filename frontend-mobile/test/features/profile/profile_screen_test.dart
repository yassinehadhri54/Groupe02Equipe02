import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/profile/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryAuthTokenStore implements AuthTokenStore {
  final Map<String, String> values = {'campussave_id_token': 'test-id-token'};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  http.Response profileResponse({
    String? name,
    String? fullName = 'amin zouaoui',
    String? email = 'amin@gmail.com',
    String? phone,
    String? photoUrl,
    String? role = 'student',
  }) {
    return http.Response(
      jsonEncode({
        'success': true,
        'user': {
          'uid': 'student-1',
          'name': name,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'photoURL': photoUrl,
          'role': role,
          'status': 'active',
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  String? authorizationHeader(http.Request request) {
    return request.headers['Authorization'] ?? request.headers['authorization'];
  }

  testWidgets('loads real profile with secure bearer token and empty states', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    http.Request? sentRequest;
    final tokenStore = _MemoryAuthTokenStore();
    final authRepository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((request) async {
        sentRequest = request;
        return profileResponse();
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(sentRequest?.method, 'GET');
    expect(sentRequest?.url.path, '/api/users/profile');
    expect(authorizationHeader(sentRequest!), 'Bearer test-id-token');
    expect(find.text('amin zouaoui'), findsOneWidget);
    expect(find.text('amin@gmail.com'), findsOneWidget);
    expect(find.text('Étudiant'), findsOneWidget);
    expect(find.text('Téléphone non renseigné'), findsOneWidget);
    expect(find.text('Statistiques bientôt disponibles'), findsOneWidget);
    expect(find.text('Malek Ben Ali'), findsNothing);
    expect(find.text('36 DT'), findsNothing);
  });

  testWidgets('missing profile fields use explicit placeholders', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final authRepository = AuthRepository(
      tokenStore: _MemoryAuthTokenStore(),
      client: MockClient(
        (_) async => profileResponse(fullName: null, email: null, role: null),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nom non renseigné'), findsOneWidget);
    expect(find.text('E-mail non renseigné'), findsOneWidget);
    expect(find.text('Téléphone non renseigné'), findsOneWidget);
    expect(find.text('Rôle non renseigné'), findsOneWidget);
    expect(find.text('Malek Ben Ali'), findsNothing);
  });

  testWidgets('401 clears the stored token and offers retry', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final tokenStore = _MemoryAuthTokenStore();
    tokenStore.values['campussave_refresh_token'] = 'test-refresh-token';
    final authRepository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Invalid or expired token."}',
          401,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ta session a expiré. Reconnecte-toi.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tokenStore.values, isEmpty);
  });

  testWidgets('403 shows access denied without clearing the session', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final tokenStore = _MemoryAuthTokenStore();
    final authRepository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient(
        (_) async =>
            http.Response('{"success":false,"message":"Access denied."}', 403),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Tu n’es pas autorisé à consulter ce profil.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tokenStore.values['campussave_id_token'], 'test-id-token');
  });

  testWidgets('network failure can be retried', (WidgetTester tester) async {
    configureViewport(tester);
    var requestCount = 0;
    final authRepository = AuthRepository(
      tokenStore: _MemoryAuthTokenStore(),
      client: MockClient((_) async {
        requestCount++;
        if (requestCount == 1) {
          throw http.ClientException('offline');
        }
        return profileResponse();
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Impossible de contacter le serveur. Vérifie ta connexion puis réessaie.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('amin zouaoui'), findsOneWidget);
  });

  testWidgets('edit sends accepted fields then reloads the profile', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final tokenStore = _MemoryAuthTokenStore();
    final requests = <http.Request>[];
    final authRepository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          return http.Response(
            '{"success":true,"message":"Profile updated successfully."}',
            200,
          );
        }
        if (requests.where((item) => item.method == 'GET').length == 1) {
          return profileResponse();
        }
        return profileResponse(name: 'Amin Zouaoui', phone: '+216 55 444 333');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(authRepository: authRepository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier le profil'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('profile-edit-email')),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-name')),
      'Amin Zouaoui',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-phone')),
      '+216 55 444 333',
    );
    tester.testTextInput.hide();
    await tester.pump();
    final saveButton = find.byKey(const ValueKey('profile-edit-save'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(requests.map((request) => request.method).toList(), [
      'GET',
      'PUT',
      'GET',
    ]);
    expect(
      requests.every((request) => request.url.path == '/api/users/profile'),
      isTrue,
    );
    expect(
      requests.every(
        (request) => authorizationHeader(request) == 'Bearer test-id-token',
      ),
      isTrue,
    );
    final updateBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(updateBody, {'name': 'Amin Zouaoui', 'phone': '+216 55 444 333'});
    expect(updateBody.containsKey('fullName'), isFalse);
    expect(updateBody.containsKey('email'), isFalse);
    expect(find.text('Amin Zouaoui'), findsOneWidget);
    expect(find.text('+216 55 444 333'), findsOneWidget);
    expect(find.text('amin@gmail.com'), findsOneWidget);
  });
}
