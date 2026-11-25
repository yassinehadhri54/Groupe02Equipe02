import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/merchant/data/merchant_api_repository.dart';
import 'package:myfirstflutterp/features/merchant/models/merchant_order.dart';
import 'package:myfirstflutterp/features/merchant/screens/merchant_reservations_screen.dart';
import 'package:myfirstflutterp/features/merchant/screens/verify_pickup_screen.dart';

class _TokenStore implements AuthTokenStore {
  final tokens = {'campussave_id_token': 'mock-auth-token'};

  @override
  Future<String?> read(String key) async => tokens[key];

  @override
  Future<void> write(String key, String value) async {
    tokens[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    tokens.remove(key);
  }
}

MerchantApiRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  _TokenStore? tokens,
}) {
  return MerchantApiRepository(
    AuthRepository(
      client: MockClient(handler),
      tokenStore: tokens ?? _TokenStore(),
    ),
  );
}

http.Response _success(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _failure(int status, String message) =>
    http.Response(jsonEncode({'success': false, 'message': message}), status);

Map<String, dynamic> _order(
  String id, {
  String? payment = 'paid',
  String status = 'pending',
  int seconds = 1795280000,
}) => {
  'reservationId': id,
  'offerId': 'offer-1',
  'offerName': 'Panier $id',
  'quantity': 2,
  'totalPrice': 7.25,
  'status': status,
  'paymentStatus': payment,
  'createdAt': {'_seconds': seconds, '_nanoseconds': 0},
};

Future<void> _show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loads reservations and sorts dated items newest first', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final repository = _repository((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/reservations/merchant');
      expect(request.headers['Authorization'], 'Bearer mock-auth-token');
      return response.future;
    });
    await _show(tester, MerchantReservationsScreen(repository: repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(
      _success([
        _order('ancien', status: 'rejected', payment: 'failed'),
        _order('récent', seconds: 1795280800),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Panier récent')).dy,
      lessThan(tester.getTopLeft(find.text('Panier ancien')).dy),
    );
    expect(find.text('7.250 DT'), findsNWidgets(2));
    expect(find.text('2 portions'), findsNWidgets(2));
    expect(find.text('Refusée'), findsOneWidget);
    expect(find.text('Échoué'), findsOneWidget);
    expect(find.text('Payé'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsNWidgets(2));
  });

  testWidgets('shows a retryable network failure and then the empty state', (
    tester,
  ) async {
    var requests = 0;
    final repository = _repository((request) async {
      if (++requests == 1) {
        throw http.ClientException('Simulated network failure');
      }
      return _success([]);
    });
    await _show(tester, MerchantReservationsScreen(repository: repository));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Impossible de contacter le serveur'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune réservation reçue.'), findsOneWidget);
    expect(requests, 2);
  });

  test('only pending paid orders can be confirmed and pending unpaid or failed orders rejected', () {
    for (final payment in [
      'paid',
      'unpaid',
      'failed',
      'processing',
      'pending',
      null,
      'unexpected',
    ]) {
      final order = MerchantOrder.fromJson(_order('test', payment: payment));
      expect(order.allows(MerchantOrderAction.confirm), payment == 'paid');
      expect(
        order.allows(MerchantOrderAction.reject),
        ['unpaid', 'failed'].contains(payment),
      );
    }
    for (final status in [
      'confirmed',
      'cancelled',
      'rejected',
      'completed',
      'unexpected',
    ]) {
      final order = MerchantOrder.fromJson(_order('test', status: status));
      expect(MerchantOrderAction.values.any(order.allows), isFalse);
    }
  });

  testWidgets(
    'confirms and rejects through dialogs, blocks duplicate writes and refreshes',
    (tester) async {
      final update = Completer<http.Response>();
      var paid = _order('paid');
      var unpaid = _order('unpaid', payment: 'unpaid', seconds: 1795279999);
      final processing = _order(
        'processing',
        payment: 'processing',
        seconds: 1795279998,
      );
      final writes = <String>[];
      var reads = 0;
      var changes = 0;
      final repository = _repository((request) async {
        if (request.method == 'GET') {
          reads++;
          return _success([paid, unpaid, processing]);
        }
        expect(request.method, 'PUT');
        final status = jsonDecode(request.body)['status'];
        writes.add('${request.url.path} $status');
        if (status == 'confirmed') {
          final response = await update.future;
          paid = {...paid, 'status': 'confirmed'};
          return response;
        }
        unpaid = {...unpaid, 'status': 'rejected'};
        return _success(unpaid);
      });

      await _show(
        tester,
        MerchantReservationsScreen(
          repository: repository,
          onChanged: () => changes++,
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('merchant-confirm-paid'));
      final reject = find.byKey(const ValueKey('merchant-reject-unpaid'));
      expect(confirm, findsOneWidget);
      expect(reject, findsOneWidget);
      expect(find.byKey(const ValueKey('merchant-reject-paid')), findsNothing);
      expect(
        find.byKey(const ValueKey('merchant-confirm-unpaid')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('merchant-reject-processing')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('merchant-confirm-processing')),
        findsNothing,
      );

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final approve = find.byKey(
        const ValueKey('merchant-confirm-status-change'),
      );
      final activate = tester.widget<FilledButton>(approve).onPressed!;
      activate();
      activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(writes, ['/api/reservations/paid/status confirmed']);
      expect(tester.widget<OutlinedButton>(reject).onPressed, isNull);
      expect(reads, 1);
      update.complete(
        _success({'reservationId': 'paid', 'status': 'confirmed'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmée'), findsOneWidget);
      expect(reads, 2);

      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(find.text('Refuser la réservation ?'), findsOneWidget);
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(writes.last, '/api/reservations/unpaid/status rejected');
      expect(writes, hasLength(2));
      expect(changes, 2);
      expect(reads, 3);
      expect(find.text('Refusée'), findsOneWidget);
    },
  );

  for (final (code, action, message, expected) in [
    (
      400,
      MerchantOrderAction.confirm,
      'Reservation must be paid before confirmation.',
      'Le paiement doit être effectué',
    ),
    (
      400,
      MerchantOrderAction.reject,
      'Cannot reject a reservation while payment is in progress or paid.',
      'Impossible de refuser',
    ),
    (401, MerchantOrderAction.confirm, 'Expired.', 'session a expiré'),
    (
      403,
      MerchantOrderAction.reject,
      'You are not allowed to update this reservation.',
      'pas autorisée',
    ),
    (404, MerchantOrderAction.confirm, 'Reservation not found.', 'introuvable'),
    (409, MerchantOrderAction.reject, 'Conflict.', 'Actualise la liste'),
  ]) {
    test('transition $action surfaces HTTP $code', () async {
      final tokens = _TokenStore();
      final repository = _repository(
        (_) async => _failure(code, message),
        tokens: tokens,
      );
      await expectLater(
        repository.updateReservationStatus('test', action),
        throwsA(
          isA<AuthException>()
              .having((error) => error.statusCode, 'status', code)
              .having((error) => error.message, 'message', contains(expected)),
        ),
      );
      expect(tokens.tokens.isEmpty, code == 401);
    });
  }

  testWidgets(
    'QR requires explicit confirmation, blocks doubles and clears the token on success',
    (tester) async {
      final token = 'Ab' * 32;
      final response = Completer<http.Response>();
      var requests = 0;
      var changes = 0;
      final repository = _repository((request) {
        requests++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/reservations/verify-qr');
        expect(jsonDecode(request.body), {'token': token});
        return response.future;
      });
      await _show(
        tester,
        VerifyPickupScreen(repository: repository, onChanged: () => changes++),
      );
      final field = find.byKey(const ValueKey('merchant-pickup-token'));
      final verify = find.widgetWithText(FilledButton, 'Vérifier le code');
      await tester.enterText(field, 'incorrect');
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(find.textContaining('Saisis un code QR valide'), findsOneWidget);
      expect(requests, 0);

      await tester.enterText(field, ' $token ');
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(requests, 0);

      await tester.tap(verify);
      await tester.pumpAndSettle();
      final accept = find.byKey(const ValueKey('merchant-confirm-pickup'));
      final activate = tester.widget<FilledButton>(accept).onPressed!;
      activate();
      activate();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, 1);
      expect(tester.widget<FilledButton>(verify).onPressed, isNull);
      response.complete(
        _success({
          'reservationId': 'pickup-1',
          'status': 'completed',
          'paymentStatus': 'paid',
        }),
      );
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(find.text('Retrait validé'), findsOneWidget);
      expect(find.textContaining('pickup-1'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
    },
  );

  for (final (code, message, expected) in [
    (400, 'Invalid QR Code.', 'Ce code QR est invalide.'),
    (400, 'Invalid or expired QR Code.', 'Ce code QR est invalide ou expiré.'),
    (400, 'QR Code has already been used.', 'Ce code QR a déjà été utilisé.'),
    (
      403,
      'You are not allowed to verify this reservation.',
      'Ce retrait n’est pas autorisé pour ton commerce.',
    ),
    (
      400,
      'Only confirmed reservations can be completed.',
      'La réservation doit être confirmée avant le retrait.',
    ),
  ]) {
    testWidgets('QR displays $message without marking the pickup as done', (
      tester,
    ) async {
      final repository = _repository((_) async => _failure(code, message));
      await _show(tester, VerifyPickupScreen(repository: repository));
      await tester.enterText(
        find.byKey(const ValueKey('merchant-pickup-token')),
        'a' * 64,
      );
      await tester.tap(find.text('Vérifier le code'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merchant-confirm-pickup')));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Retrait validé'), findsNothing);
    });
  }
}
