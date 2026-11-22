// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/widgets/main_navigation.dart';
import 'package:myfirstflutterp/features/auth/screens/login_screen.dart';
import 'package:myfirstflutterp/features/auth/screens/register_screen.dart';
import 'package:myfirstflutterp/features/bookings/screens/booking_summary_screen.dart';
import 'package:myfirstflutterp/features/bookings/data/reservation_repository.dart';
import 'package:myfirstflutterp/features/offers/screens/offer_detail_screen.dart';
import 'package:myfirstflutterp/features/home/screens/home_screen.dart';
import 'package:myfirstflutterp/features/search/data/shop_repository.dart';
import 'package:myfirstflutterp/features/search/models/shop_offer.dart';
import 'package:myfirstflutterp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryAuthTokenStore implements AuthTokenStore {
  _MemoryAuthTokenStore({bool authenticated = false}) {
    if (authenticated) values['campussave_id_token'] = 'test-token';
  }

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

const _testReservationsResponse =
    '{"success":true,"count":4,"data":['
    '{"reservationId":"res-pending","offerId":"offer-1","offerName":"Sandwich frais","shopName":"Commerce test","quantity":2,"unitPrice":3.5,"totalPrice":7,"status":"pending","paymentStatus":"unpaid"},'
    '{"reservationId":"res-confirmed","offerId":"offer-2","offerName":"Panier test","shopName":"Commerce test","quantity":1,"unitPrice":5,"totalPrice":5,"status":"confirmed","paymentStatus":"paid"},'
    '{"reservationId":"res-completed","offerId":"offer-3","offerName":"Repas terminé","quantity":1,"unitPrice":4,"totalPrice":4,"status":"completed","paymentStatus":"paid"},'
    '{"reservationId":"res-cancelled","offerId":"offer-4","offerName":"Repas annulé","quantity":1,"unitPrice":2,"totalPrice":2,"status":"cancelled","paymentStatus":"failed"}]}';

const _createdReservationResponse =
    '{"success":true,"data":{"reservationId":"res-created","offerId":"offer-1","offerName":"Sandwich frais","shopName":"Commerce test","quantity":2,"unitPrice":3.5,"totalPrice":7,"status":"pending","paymentStatus":"unpaid"}}';

AuthRepository _createTestAuthRepository({bool authenticated = false}) {
  return AuthRepository(
    tokenStore: _MemoryAuthTokenStore(authenticated: authenticated),
    client: MockClient((request) async {
      if (request.url.path.endsWith('/api/auth/login')) {
        return http.Response(
          '{"success":true,"user":{"uid":"student-1","email":"etudiant@example.com","fullName":"Malek Campus","role":"student","status":"active"},"tokens":{"idToken":"test-token","refreshToken":"test-refresh","expiresIn":"3600"}}',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/api/auth/register')) {
        return http.Response(
          '{"success":true,"user":{"uid":"student-1","email":"malek@example.com","fullName":"Malek Campus","role":"student","status":"active"}}',
          201,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/api/auth/me')) {
        return http.Response(
          '{"success":true,"user":{"uid":"student-1","email":"etudiant@example.com","fullName":"Malek Campus","role":"student","status":"active"}}',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path == '/api/offers') {
        return http.Response(
          '''
          {"success":true,"count":2,"data":[
            {"id":"offer-1","name":"Sandwich frais","description":"API test offer.","category":"Sandwichs","originalPrice":7,"discountPrice":3.5,"quantity":10,"availableQuantity":5,"imageURL":null,"pickupStart":"12:00","pickupEnd":"14:00","shopId":"shop-1","shopName":"Commerce test","status":"available"},
            {"id":"offer-2","name":"Panier surprise","description":"Second API test offer.","category":"Paniers","originalPrice":10,"discountPrice":5,"quantity":4,"availableQuantity":2,"imageURL":null,"shopId":"shop-1","shopName":"Commerce test","status":"available"}
          ]}
          ''',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path == '/api/offers/offer-1') {
        return http.Response(
          '{"success":true,"data":{"id":"offer-1","name":"Sandwich frais","description":"API test offer.","category":"Sandwichs","originalPrice":7,"discountPrice":3.5,"quantity":10,"availableQuantity":5,"imageURL":null,"pickupStart":"12:00","pickupEnd":"14:00","shopId":"shop-1","shopName":"Commerce test","status":"available"}}',
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (request.url.path == '/api/reservations/my-reservations') {
        return http.Response(_testReservationsResponse, 200);
      }
      if (request.url.path == '/api/reservations' && request.method == 'POST') {
        return http.Response(_createdReservationResponse, 201);
      }
      if (request.url.path == '/api/reservations/res-confirmed/cancel') {
        return http.Response(
          '{"success":true,"data":{"reservationId":"res-confirmed","offerId":"offer-2","offerName":"Panier test","shopName":"Commerce test","quantity":1,"unitPrice":5,"totalPrice":5,"status":"cancelled","paymentStatus":"failed"}}',
          200,
        );
      }
      if (request.url.path.endsWith('/qr')) {
        return http.Response(
          '{"success":false,"message":"Reservation must be paid before generating QR Code."}',
          400,
        );
      }
      return http.Response('{"success":false,"message":"Not found"}', 404);
    }),
  );
}

ShopRepository _createTestShopRepository() {
  return ShopRepository(
    authRepository: _createTestAuthRepository(authenticated: true),
  );
}

ReservationRepository _createTestReservationRepository() {
  return ReservationRepository(
    authRepository: _createTestAuthRepository(authenticated: true),
  );
}

void _configureViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _expectAuthHeaderAndFooter(
  WidgetTester tester,
  String footerKey,
) async {
  final topWave = tester.getRect(find.byKey(const ValueKey('auth-top-wave')));
  final slogan = tester.getRect(find.byKey(const ValueKey('auth-slogan')));
  expect(slogan.top, greaterThanOrEqualTo(topWave.bottom));
  expect(slogan.right, lessThanOrEqualTo(tester.view.physicalSize.width));

  final footer = find.byKey(ValueKey(footerKey));
  await tester.ensureVisible(footer);
  await tester.pumpAndSettle();

  final footerRect = tester.getRect(footer);
  final bottomWave = tester.getRect(
    find.byKey(const ValueKey('auth-bottom-wave')),
  );
  expect(footerRect.bottom, lessThanOrEqualTo(bottomWave.top));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy session tokens migrate to secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'campussave_auth_session': '''
        {"user":{"uid":"student-1","email":"student@example.com","fullName":"Student","role":"student","status":"active"},"idToken":"legacy-id","refreshToken":"legacy-refresh"}
      ''',
    });
    final tokenStore = _MemoryAuthTokenStore();
    final repository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    final session = await repository.loadSession();

    expect(session?.idToken, 'legacy-id');
    expect(session?.refreshToken, 'legacy-refresh');
    expect(await tokenStore.read('campussave_id_token'), 'legacy-id');
    expect(await tokenStore.read('campussave_refresh_token'), 'legacy-refresh');
    expect(
      (await SharedPreferences.getInstance()).getString(
        'campussave_auth_session',
      ),
      isNull,
    );
  });

  test('logout clears secure tokens and local user', () async {
    final tokenStore = _MemoryAuthTokenStore();
    final repository = AuthRepository(
      tokenStore: tokenStore,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await repository.saveSession(
      const AuthSession(
        user: AuthUser(
          uid: 'student-1',
          email: 'student@example.com',
          fullName: 'Student',
          role: 'student',
          status: 'active',
        ),
        idToken: 'id-token',
        refreshToken: 'refresh-token',
      ),
    );

    await repository.clearSession();

    expect(await tokenStore.read('campussave_id_token'), isNull);
    expect(await tokenStore.read('campussave_refresh_token'), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('campussave_auth_user'),
      isNull,
    );
  });

  testWidgets('login fits 360x740 and scrolls its footer above the wave', (
    WidgetTester tester,
  ) async {
    const size = Size(360, 740);
    _configureViewport(tester, size);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );

    expect(find.byKey(const ValueKey('auth-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-slogan')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-illustration')), findsOneWidget);
    await _expectAuthHeaderAndFooter(tester, 'login-register');

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('login-email')));
    await tester.tap(find.byKey(const ValueKey('login-email')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('login-register')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('login-register'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('auth-bottom-wave'))).top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login fits 412x915 with its logo outside the top wave', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );

    await _expectAuthHeaderAndFooter(tester, 'login-register');
    expect(tester.takeException(), isNull);
  });

  testWidgets('register fits 360x740 and keeps controls above the wave', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(360, 740));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterScreen(authRepository: _createTestAuthRepository()),
      ),
    );

    expect(find.byKey(const ValueKey('auth-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-slogan')), findsOneWidget);
    await _expectAuthHeaderAndFooter(tester, 'register-login');

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('register-confirm-password')),
    );
    await tester.tap(find.byKey(const ValueKey('register-confirm-password')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('register-login')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('register-login'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('auth-bottom-wave'))).top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('register fits 412x915 and keeps its footer scrollable', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
    );

    await _expectAuthHeaderAndFooter(tester, 'register-login');
    expect(tester.takeException(), isNull);
  });

  testWidgets('home header and circular promo stay responsive on mobile', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(360, 740));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: _createTestShopRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('💡 Sandwichs'), findsOneWidget);
    expect(find.text('API test offer.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('promo-banner-offer-1')),
        matching: find.byType(ClipOval),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('offer-search-field'))).height,
      tester.getSize(find.byKey(const ValueKey('header-filter-button'))).height,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('offer-search-field')))
          .decoration!
          .filled,
      isFalse,
    );

    await tester.drag(
      find.byKey(const ValueKey('promo-carousel')),
      const Offset(-240, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('💡 Paniers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('register validates its fields and toggles password visibility', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(800, 1600));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterScreen(authRepository: _createTestAuthRepository()),
      ),
    );

    final submit = find.byKey(const ValueKey('register-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Saisis ton nom complet'), findsOneWidget);
    expect(find.text('Saisis une adresse e-mail valide'), findsOneWidget);
    expect(find.text('Au moins 8 caractères requis'), findsOneWidget);
    expect(find.text('Confirme ton mot de passe'), findsOneWidget);

    final password = find.byKey(const ValueKey('register-password'));
    final confirmPassword = find.byKey(
      const ValueKey('register-confirm-password'),
    );
    final passwordInput = find.descendant(
      of: password,
      matching: find.byType(TextField),
    );
    final confirmPasswordInput = find.descendant(
      of: confirmPassword,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe').first);
    await tester.pump();
    expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
    await tester.tap(find.byTooltip('Afficher la confirmation'));
    await tester.pump();
    expect(tester.widget<TextField>(confirmPasswordInput).obscureText, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('register-name')),
      'Malek Campus',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'malek@example.com',
    );
    await tester.enterText(password, 'motdepasse1');
    await tester.enterText(confirmPassword, 'different1');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);

    await tester.enterText(confirmPassword, 'motdepasse1');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
      find.text('Compte créé. Tu peux maintenant te connecter.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('application starts on the login screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CampusSaveApp(authRepository: _createTestAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
  });

  testWidgets('invalid login form stays on the login screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CampusSaveApp(authRepository: _createTestAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
    expect(find.text('Saisis une adresse e-mail valide'), findsOneWidget);
    expect(find.text('Saisis ton mot de passe'), findsOneWidget);
  });

  testWidgets('valid login opens navigation without creating a session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CampusSaveApp(authRepository: _createTestAuthRepository()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'etudiant@example.com');
    await tester.enterText(fields.at(1), 'demo');
    tester.testTextInput.hide();
    await tester.pump();
    final loginButton = find.widgetWithText(ElevatedButton, 'Se connecter');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Saisis une adresse e-mail valide'), findsNothing);
    expect(find.text('Saisis ton mot de passe'), findsNothing);
    expect(find.byType(MainNavigation), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byKey(const ValueKey('main-navigation-bar')), findsOneWidget);
    expect(find.text('Offres disponibles'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(MainNavigation))).canPop(),
      isFalse,
    );
  });

  testWidgets('registration opens and back returns to login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CampusSaveApp(authRepository: _createTestAuthRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("S'inscrire"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('register-login')));
    await tester.tap(find.byKey(const ValueKey('register-login')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('CampusSave home displays offers and filters by category', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainNavigation(
          authRepository: _createTestAuthRepository(),
          offersRepository: _createTestShopRepository(),
          reservationRepository: _createTestReservationRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('Offres disponibles'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Panier surprise'), findsWidgets);

    final searchField = find.byKey(const ValueKey('offer-search-field'));
    await tester.enterText(searchField, 'Sandwich');
    await tester.pump();

    expect(find.text('Sandwich frais'), findsWidgets);
    expect(find.text('Panier surprise'), findsNothing);

    await tester.enterText(searchField, '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-filter-Sandwichs')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Sandwich frais'), findsWidgets);
    expect(find.text('Panier surprise'), findsNothing);

    final sandwichOfferCard = find.byKey(
      const ValueKey('offer-card-Sandwich frais'),
    );
    await tester.tap(sandwichOfferCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 350));

    final detailScreen = find.byKey(const ValueKey('offer-detail-screen'));
    expect(detailScreen, findsOneWidget);
    expect(
      find.descendant(of: detailScreen, matching: find.text('Sandwich frais')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('offer-total-value'))).data,
      '3.500 DT',
    );
    expect(
      find.byKey(const ValueKey('offer-available-quantity')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('increase-quantity')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('offer-quantity-value')))
          .data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('offer-total-value'))).data,
      '7.000 DT',
    );

    await tester.tap(find.byKey(const ValueKey('reserve-offer-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final bookingSummary = find.byKey(const ValueKey('booking-summary-screen'));
    expect(bookingSummary, findsOneWidget);
    expect(
      find.descendant(
        of: bookingSummary,
        matching: find.text('Sandwich frais'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-quantity-value')))
          .data,
      '2 portions',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-unit-price')))
          .data,
      '3.500 DT',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-estimated-total')))
          .data,
      '7.000 DT',
    );

    await tester.tap(find.byKey(const ValueKey('confirm-booking-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Réservation enregistrée'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('created-reservation-id')))
          .data,
      'res-created',
    );
    expect(find.text('Non payé'), findsOneWidget);
    expect(find.textContaining('QR'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('booking-summary-done')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offer-detail-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offer-detail-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Offres disponibles'), findsOneWidget);
  });

  testWidgets('Booking summary keeps its confirm action visible on mobile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BookingSummaryScreen(
          offer: const ShopOffer(
            id: 'offer-1',
            name: 'Sandwich frais',
            shopName: 'Commerce test',
            imageUrl: null,
            discountPrice: 3.5,
            category: 'Sandwichs',
            description: 'Un sandwich frais.',
          ),
          quantity: 2,
          repository: _createTestReservationRepository(),
        ),
      ),
    );
    await tester.pump();

    final confirmButton = find.byKey(const ValueKey('confirm-booking-button'));
    expect(confirmButton, findsOneWidget);
    expect(tester.getBottomRight(confirmButton).dy, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking confirmation cannot submit twice while pending', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(390, 844));
    final response = Completer<http.Response>();
    var postCount = 0;
    final repository = ReservationRepository(
      authRepository: AuthRepository(
        tokenStore: _MemoryAuthTokenStore(authenticated: true),
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/api/reservations') {
            postCount++;
            return response.future;
          }
          return http.Response('{"success":true,"data":[]}', 200);
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BookingSummaryScreen(
          offer: const ShopOffer(
            id: 'offer-1',
            name: 'Sandwich frais',
            shopName: 'Commerce test',
            imageUrl: null,
            discountPrice: 3.5,
            category: 'Sandwichs',
            description: 'Un sandwich frais.',
          ),
          quantity: 2,
          repository: repository,
        ),
      ),
    );

    final confirmButton = find.byKey(const ValueKey('confirm-booking-button'));
    await tester.tap(confirmButton);
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pump();
    expect(postCount, 1);

    response.complete(http.Response(_createdReservationResponse, 201));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Réservation enregistrée'), findsOneWidget);
  });

  testWidgets('booking card opens its selected detail without another navbar', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(800, 1600));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainNavigation(
          authRepository: _createTestAuthRepository(),
          offersRepository: _createTestShopRepository(),
          reservationRepository: _createTestReservationRepository(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('navigation-bookings')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('booking-card-res-confirmed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('booking-detail-screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-detail-reference')),
      findsOneWidget,
    );
    expect(find.text('res-confirmed'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-detail-name')))
          .data,
      'Panier test',
    );
    expect(find.text('1 portion'), findsOneWidget);
    expect(find.text('Payé'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-qr-load')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-qr-image')), findsNothing);
    expect(find.textContaining('DÉMONSTRATION'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-detail-total')))
          .data,
      '5.000 DT',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('booking-detail-screen')),
        matching: find.byKey(const ValueKey('main-navigation-bar')),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('booking-detail-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('bookings-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-navigation-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking detail back preserves the selected filter', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainNavigation(
          authRepository: _createTestAuthRepository(),
          offersRepository: _createTestShopRepository(),
          reservationRepository: _createTestReservationRepository(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('navigation-bookings')));
    await tester.pump();
    await tester.pump();
    final completedFilter = find.byKey(
      const ValueKey('booking-filter-Terminées'),
    );
    await tester.ensureVisible(completedFilter);
    await tester.tap(completedFilter);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('booking-card-res-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('booking-card-res-pending')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('booking-card-res-completed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('res-completed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-detail-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byKey(const ValueKey('booking-card-res-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('booking-card-res-pending')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('main navigation switches tabs and preserves booking flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainNavigation(
          authRepository: _createTestAuthRepository(),
          offersRepository: _createTestShopRepository(),
          reservationRepository: _createTestReservationRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('offer-search-field')),
      'Sandwich',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('navigation-search')));
    await tester.pump();
    expect(find.byKey(const ValueKey('search-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('navigation-bookings')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bookings-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('navigation-profile')));
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('navigation-home')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('offer-search-field')))
          .controller
          ?.text,
      'Sandwich',
    );
    await tester.enterText(
      find.byKey(const ValueKey('offer-search-field')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('offer-card-Sandwich frais')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(OfferDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reserve-offer-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byKey(const ValueKey('booking-summary-screen')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('booking-summary-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(OfferDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offer-detail-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-navigation-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
