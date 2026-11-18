// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/core/widgets/main_navigation.dart';
import 'package:myfirstflutterp/features/auth/screens/login_screen.dart';
import 'package:myfirstflutterp/features/auth/screens/register_screen.dart';
import 'package:myfirstflutterp/features/bookings/screens/booking_summary_screen.dart';
import 'package:myfirstflutterp/features/offers/screens/offer_detail_screen.dart';
import 'package:myfirstflutterp/features/offers/models/food_offer.dart';
import 'package:myfirstflutterp/features/home/screens/home_screen.dart';
import 'package:myfirstflutterp/main.dart';

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
      MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
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
      MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('💡 Offre du jour'), findsOneWidget);
    expect(find.text('Mange bien,\ngaspille moins ! 🌍'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('promo-banner-0')),
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
    expect(find.text('💡 Anti-gaspillage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('register validates its fields and toggles password visibility', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(800, 1600));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
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
      find.text('Formulaire valide ! Inscription bientôt disponible.'),
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

    await tester.pumpWidget(const CampusSaveApp());

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

    await tester.pumpWidget(const CampusSaveApp());

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

    await tester.pumpWidget(const CampusSaveApp());

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

    await tester.pumpWidget(const CampusSaveApp());

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
      MaterialApp(theme: AppTheme.light, home: const MainNavigation()),
    );
    await tester.pump();

    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('CampusSave 🌱'), findsOneWidget);
    expect(find.text('Offres disponibles'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Panier surprise'), findsOneWidget);

    final searchField = find.byKey(const ValueKey('offer-search-field'));
    await tester.enterText(searchField, 'Sandwich');
    await tester.pump();

    expect(find.text('Sandwich frais'), findsOneWidget);
    expect(find.text('Panier surprise'), findsNothing);

    await tester.enterText(searchField, '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-filter-Sandwichs')));
    await tester.pump();

    expect(find.text('Sandwich frais'), findsOneWidget);
    expect(find.text('Panier surprise'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('offer-card-Sandwich frais')));
    await tester.pump();
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

    await tester.tap(find.byKey(const ValueKey('decrease-quantity')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('offer-quantity-value')))
          .data,
      '1',
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
          .widget<Text>(find.byKey(const ValueKey('booking-initial-total')))
          .data,
      '14.000 DT',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-discount-total')))
          .data,
      '−7.000 DT',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-final-total')))
          .data,
      '7.000 DT',
    );

    await tester.tap(find.byKey(const ValueKey('confirm-booking-button')));
    await tester.pump();
    expect(
      find.text("Mode démonstration : la réservation n'a pas été enregistrée."),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('booking-summary-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
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
        home: const BookingSummaryScreen(
          offer: FoodOffer(
            name: 'Sandwich frais',
            shop: 'Snack Campus',
            imageUrl: 'https://example.com/offer.jpg',
            price: 3.5,
            oldPrice: 7,
            category: 'Sandwichs',
            description: 'Un sandwich frais.',
          ),
          quantity: 2,
        ),
      ),
    );
    await tester.pump();

    final confirmButton = find.byKey(const ValueKey('confirm-booking-button'));
    expect(confirmButton, findsOneWidget);
    expect(tester.getBottomRight(confirmButton).dy, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking card opens its selected detail without another navbar', (
    WidgetTester tester,
  ) async {
    _configureViewport(tester, const Size(800, 1600));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MainNavigation()),
    );

    await tester.tap(find.byKey(const ValueKey('navigation-bookings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('booking-card-CS-1002')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('booking-detail-screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-detail-reference')),
      findsOneWidget,
    );
    expect(find.text('CS-1002'), findsOneWidget);
    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey('booking-detail-name')),
      ).data,
      'Sandwich poulet',
    );
    expect(find.text('2 portions'), findsOneWidget);
    expect(
      find.text('Snack Campus, Avenue Hédi Nouira, Tunis'),
      findsOneWidget,
    );
    expect(find.text('DEMO-915204'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-detail-total')))
          .data,
      '7.000 DT',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-detail-savings')))
          .data,
      '7.000 DT',
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
    _configureViewport(tester, const Size(800, 1600));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MainNavigation()),
    );

    await tester.tap(find.byKey(const ValueKey('navigation-bookings')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('booking-filter-Terminées')));
    await tester.pump();
    expect(find.byKey(const ValueKey('booking-card-CS-1003')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-card-CS-1001')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('booking-card-CS-1003')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('CS-1003'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-detail-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('booking-card-CS-1003')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-card-CS-1001')), findsNothing);
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
      MaterialApp(theme: AppTheme.light, home: const MainNavigation()),
    );
    await tester.pump();

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
