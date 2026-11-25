import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/auth/screens/login_screen.dart';
import 'package:myfirstflutterp/features/auth/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryAuthTokenStore implements AuthTokenStore {
  final Map<String, String> values = {};

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'registration diagnostics classify network exceptions without secrets',
    () async {
      final previousDebugPrint = debugPrint;
      final diagnosticLogs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null &&
            message.startsWith('[AuthRepository.register]')) {
          diagnosticLogs.add(message);
        }
      };
      addTearDown(() => debugPrint = previousDebugPrint);

      final repository = AuthRepository(
        client: MockClient((_) async {
          throw const SocketException('network unavailable');
        }),
      );

      await expectLater(
        repository.register(
          fullName: 'CampusSave Student',
          email: 'student@example.com',
          password: 'securepass123',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(diagnosticLogs, hasLength(1));
      expect(diagnosticLogs.single, contains('outcome=network_error'));
      expect(diagnosticLogs.single, contains('exceptionType=SocketException'));
      expect(diagnosticLogs.single, contains('durationMs='));
      expect(diagnosticLogs.single, contains('httpStatus=none'));
      expect(
        diagnosticLogs.single,
        contains('endpoint=http://10.0.2.2:5000/api/auth/register'),
      );
      expect(diagnosticLogs.single, isNot(contains('student@example.com')));
      expect(diagnosticLogs.single, isNot(contains('securepass123')));
    },
  );

  test('registration diagnostics include HTTP response status', () async {
    final previousDebugPrint = debugPrint;
    final diagnosticLogs = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.startsWith('[AuthRepository.register]')) {
        diagnosticLogs.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final repository = AuthRepository(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Email already exists."}',
          409,
        ),
      ),
    );

    await expectLater(
      repository.register(
        fullName: 'CampusSave Student',
        email: 'student@example.com',
        password: 'securepass123',
      ),
      throwsA(isA<AuthException>()),
    );

    expect(diagnosticLogs, hasLength(1));
    expect(diagnosticLogs.single, contains('httpStatus=409'));
    expect(diagnosticLogs.single, contains('exceptionType=AuthException'));
    expect(diagnosticLogs.single, isNot(contains('student@example.com')));
    expect(diagnosticLogs.single, isNot(contains('securepass123')));
  });

  test(
    'registration distinguishes a timeout from a network or HTTP error',
    () async {
      var attempts = 0;
      final repository = AuthRepository(
        client: MockClient((_) async {
          attempts++;
          throw TimeoutException('Simulated timeout');
        }),
      );

      await expectLater(
        repository.register(
          fullName: 'CampusSave Student',
          email: 'student@example.com',
          password: 'securepass123',
        ),
        throwsA(
          isA<AuthException>()
              .having(
                (error) => error.message,
                'message',
                contains('pas répondu à temps'),
              )
              .having((error) => error.statusCode, 'HTTP status', isNull)
              .having((error) => error.retryable, 'retry action', isFalse),
        ),
      );
      expect(attempts, 1);
    },
  );

  for (final (code, body, message) in [
    (201, '[]', 'Réponse invalide du serveur.'),
    (201, '{"success":true,"user":{}}', 'Réponse invalide du serveur.'),
    (400, '{"message":42}', 'Le serveur a retourné une erreur (400).'),
    (409, 'Conflict', 'Cette adresse e-mail est déjà utilisée.'),
    (
      500,
      '<html>Internal Server Error</html>',
      'Une erreur serveur est survenue.',
    ),
  ]) {
    test(
      'registration keeps HTTP $code with an unexpected response body',
      () async {
        final repository = AuthRepository(
          client: MockClient((_) async => http.Response(body, code)),
        );
        await expectLater(
          repository.register(
            fullName: 'CampusSave Student',
            email: 'student@example.com',
            password: 'securepass123',
          ),
          throwsA(
            isA<AuthException>()
                .having((error) => error.statusCode, 'HTTP status', code)
                .having((error) => error.message, 'message', contains(message)),
          ),
        );
      },
    );
  }

  Future<void> showRegister(
    WidgetTester tester,
    AuthRepository repository, {
    bool fromLogin = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: fromLogin
            ? LoginScreen(authRepository: repository)
            : RegisterScreen(authRepository: repository),
      ),
    );

    if (fromLogin) {
      await tester.tap(find.byKey(const ValueKey('login-register')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('register-name')),
      '  CampusSave Student  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'student@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'securepass123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'securepass123',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
  }

  testWidgets(
    'merchant signup sends merchant role and explains the next step',
    (tester) async {
      late http.Request sent;
      final repository = AuthRepository(
        tokenStore: _MemoryAuthTokenStore(),
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            '{"success":true,"user":{"uid":"merchant-1","email":"student@example.com",'
            '"fullName":"CampusSave Student","role":"merchant","status":"pending"}}',
            201,
          );
        }),
      );
      await showRegister(tester, repository, fromLogin: true);
      await tester.tap(find.byKey(const ValueKey('register-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commerçant').last);
      await tester.pumpAndSettle();
      await fillValidForm(tester);
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();
      expect(sent.url.path, '/api/auth/register');
      expect(jsonDecode(sent.body)['role'], 'merchant');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Compte créé. Connecte-toi pour inscrire ton commerce.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('register sends expected JSON and returns to login on HTTP 201', (
    WidgetTester tester,
  ) async {
    http.Request? sentRequest;
    final tokenStore = _MemoryAuthTokenStore();
    final repository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'user': {
              'uid': 'student-1',
              'email': 'student@example.com',
              'fullName': 'CampusSave Student',
              'role': 'student',
              'status': 'active',
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await showRegister(tester, repository, fromLogin: true);
    await fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    expect(sentRequest?.method, 'POST');
    expect(sentRequest?.url.path, '/api/auth/register');
    expect(sentRequest?.headers['content-type'], 'application/json');
    expect(jsonDecode(sentRequest!.body), {
      'fullName': 'CampusSave Student',
      'email': 'student@example.com',
      'password': 'securepass123',
      'role': 'student',
    });
    expect(tokenStore.values, isEmpty);
    expect(
      find.text('Compte créé. Tu peux maintenant te connecter.'),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('email already used displays a clear message', (
    WidgetTester tester,
  ) async {
    final repository = AuthRepository(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Email already exists."}',
          409,
        ),
      ),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cette adresse e-mail est déjà utilisée.'),
      findsOneWidget,
    );
  });

  testWidgets('server error is shown without creating a session', (
    WidgetTester tester,
  ) async {
    final tokenStore = _MemoryAuthTokenStore();
    final repository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Registration failed."}',
          500,
        ),
      ),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Une erreur serveur est survenue. Réessaie plus tard.'),
      findsOneWidget,
    );
    expect(tokenStore.values, isEmpty);
  });

  testWidgets('HTTP 400 validation message is shown in French', (
    WidgetTester tester,
  ) async {
    final repository = AuthRepository(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Invalid email format."}',
          400,
        ),
      ),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    final snackBars = tester.widgetList<SnackBar>(find.byType(SnackBar));
    final displayedMessage = snackBars
        .map((snackBar) => (snackBar.content as Text).data)
        .join(' | ');
    expect(displayedMessage, 'Saisis une adresse e-mail valide.');
  });

  testWidgets('short password is rejected without a request', (
    WidgetTester tester,
  ) async {
    var requestCount = 0;
    final repository = AuthRepository(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 201);
      }),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'short7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'short7',
    );

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pump();

    expect(find.text('Au moins 8 caractères requis'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('mismatched confirmation is rejected without a request', (
    WidgetTester tester,
  ) async {
    var requestCount = 0;
    final repository = AuthRepository(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 201);
      }),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'differentpass',
    );

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('network failure offers retry and does not create a session', (
    WidgetTester tester,
  ) async {
    var requestCount = 0;
    final tokenStore = _MemoryAuthTokenStore();
    final repository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((_) async {
        requestCount++;
        if (requestCount == 1) {
          throw const SocketException('server unavailable');
        }
        return http.Response(
          '{"success":true,"user":{"uid":"student-1","email":"student@example.com","fullName":"CampusSave Student","role":"student","status":"active"}}',
          201,
        );
      }),
    );
    await showRegister(tester, repository, fromLogin: true);
    await fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Impossible de contacter le serveur. Vérifie ta connexion puis réessaie.',
      ),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tokenStore.values, isEmpty);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
    expect(tokenStore.values, isEmpty);
  });

  testWidgets('loading prevents a duplicate registration submission', (
    WidgetTester tester,
  ) async {
    final response = Completer<http.Response>();
    var requestCount = 0;
    final repository = AuthRepository(
      client: MockClient((_) {
        requestCount++;
        return response.future;
      }),
    );
    await showRegister(tester, repository);
    await fillValidForm(tester);

    final submit = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('register-submit')),
    );
    submit.onPressed!();
    submit.onPressed!();
    await tester.pump();
    await tester.pump();

    expect(requestCount, 1);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('register-submit')))
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(
      http.Response(
        '{"success":true,"user":{"uid":"student-1","email":"student@example.com","fullName":"CampusSave Student","role":"student","status":"active"}}',
        201,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Compte créé. Tu peux maintenant te connecter.'),
      findsOneWidget,
    );
  });

  testWidgets('Google registration is disabled and marked unavailable', (
    WidgetTester tester,
  ) async {
    await showRegister(tester, AuthRepository());

    final googleButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(googleButton.onPressed, isNull);
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });
}
