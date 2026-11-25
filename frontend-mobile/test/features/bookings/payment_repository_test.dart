import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
import 'package:myfirstflutterp/features/bookings/data/payment_repository.dart';
import 'package:myfirstflutterp/features/bookings/data/reservation_repository.dart';
import 'package:myfirstflutterp/features/bookings/models/booking.dart';
import 'package:myfirstflutterp/features/bookings/screens/booking_detail_screen.dart';

class _TokenStore implements AuthTokenStore {
  @override
  Future<String?> read(String key) async =>
      key == 'campussave_id_token' ? 'test-id-token' : null;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> write(String key, String value) async {}
}

AuthRepository _authRepository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return AuthRepository(client: MockClient(handler), tokenStore: _TokenStore());
}

http.Response _success(Object data, {int statusCode = 200}) {
  return http.Response(
    jsonEncode({'success': true, 'data': data}),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

const _unpaidBooking = {
  'reservationId': 'reservation-1',
  'offerId': 'offer-1',
  'offerName': 'Offre test',
  'quantity': 1,
  'unitPrice': 3.5,
  'totalPrice': 3.5,
  'status': 'pending',
  'paymentStatus': 'unpaid',
};

const _paidBooking = {
  'reservationId': 'reservation-1',
  'offerId': 'offer-1',
  'offerName': 'Offre test',
  'quantity': 1,
  'unitPrice': 3.5,
  'totalPrice': 3.5,
  'status': 'pending',
  'paymentStatus': 'paid',
};

const _qrDataUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
    '/x8AAwMCAO+/l2cAAAAASUVORK5CYII=';

void main() {
  group('PaymentRepository', () {
    test(
      'reads Mock and Sandbox modes from the authenticated config route',
      () async {
        final requested = <String>[];
        final authRepository = _authRepository((request) async {
          requested.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer test-id-token');
          return _success({'mode': requested.length == 1 ? 'mock' : 'sandbox'});
        });
        final repository = PaymentRepository(authRepository: authRepository);

        expect(await repository.fetchMode(), PaymentMode.mock);
        expect(await repository.fetchMode(), PaymentMode.sandbox);
        expect(requested, ['/api/payments/config', '/api/payments/config']);
      },
    );

    test('keeps an unrecognized mode disabled instead of guessing', () async {
      final repository = PaymentRepository(
        authRepository: _authRepository(
          (_) async => _success({'mode': 'unexpected'}),
        ),
      );

      expect(await repository.fetchMode(), PaymentMode.unknown);
    });

    test('posts the reservation ID and maps a successful initiation', () async {
      late http.Request sent;
      final repository = PaymentRepository(
        authRepository: _authRepository((request) async {
          sent = request;
          return _success({
            'paymentId': 'payment-1',
            'reservationId': 'reservation-1',
            'mode': 'mock',
            'status': 'pending',
          }, statusCode: 201);
        }),
      );

      final payment = await repository.initiatePayment('reservation-1');

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/payments/initiate');
      expect(jsonDecode(sent.body), {'reservationId': 'reservation-1'});
      expect(payment.id, 'payment-1');
      expect(payment.mode, PaymentMode.mock);
      expect(payment.status, 'pending');
    });

    test('confirms Mock and reads the authoritative payment status', () async {
      final requested = <String>[];
      final repository = PaymentRepository(
        authRepository: _authRepository((request) async {
          requested.add('${request.method} ${request.url.path}');
          if (request.method == 'POST') {
            return _success({
              'paymentId': 'payment-1',
              'status': 'paid',
              'message': 'Mock payment confirmed successfully.',
            });
          }
          return _success({
            'paymentId': 'payment-1',
            'reservationId': 'reservation-1',
            'mode': 'mock',
            'status': 'paid',
          });
        }),
      );

      final confirmed = await repository.confirmMockPayment('payment-1');
      final actual = await repository.fetchPayment('payment-1');

      expect(confirmed.status, 'paid');
      expect(actual.status, 'paid');
      expect(actual.mode, PaymentMode.mock);
      expect(requested, [
        'POST /api/payments/payment-1/confirm-mock',
        'GET /api/payments/payment-1',
      ]);
    });

    test('surfaces a rejected confirmation and network failures', () async {
      final rejected = PaymentRepository(
        authRepository: _authRepository(
          (_) async => http.Response(
            '{"success":false,"message":"Mock payment confirmation is disabled."}',
            400,
          ),
        ),
      );
      await expectLater(
        rejected.confirmMockPayment('payment-1'),
        throwsA(
          isA<PaymentException>().having(
            (error) => error.statusCode,
            'statusCode',
            400,
          ),
        ),
      );

      final offline = PaymentRepository(
        authRepository: _authRepository(
          (_) async => throw const SocketException('offline'),
        ),
      );
      await expectLater(
        offline.fetchMode(),
        throwsA(
          isA<PaymentException>().having(
            (error) => error.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    });
  });

  group('BookingDetailScreen payment flow', () {
    testWidgets(
      'requires explicit confirmation and verifies payment before showing QR',
      (tester) async {
        final requested = <String>[];
        final authRepository = _authRepository((request) async {
          requested.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/payments/config') {
            return _success({'mode': 'mock'});
          }
          if (request.url.path == '/api/payments/initiate') {
            expect(jsonDecode(request.body), {
              'reservationId': 'reservation-1',
            });
            return _success({
              'paymentId': 'payment-1',
              'reservationId': 'reservation-1',
              'mode': 'mock',
              'status': 'pending',
            }, statusCode: 201);
          }
          if (request.url.path == '/api/payments/payment-1/confirm-mock') {
            return _success({'paymentId': 'payment-1', 'status': 'paid'});
          }
          if (request.url.path == '/api/payments/payment-1') {
            return _success({
              'paymentId': 'payment-1',
              'reservationId': 'reservation-1',
              'mode': 'mock',
              'status': 'paid',
            });
          }
          if (request.url.path == '/api/reservations/my-reservations') {
            return http.Response(
              jsonEncode({
                'success': true,
                'count': 1,
                'data': [_paidBooking],
              }),
              200,
            );
          }
          if (request.url.path == '/api/reservations/reservation-1/qr') {
            return _success({
              'reservationId': 'reservation-1',
              'qrCode': _qrDataUrl,
              'token': 'raw-qr-token-must-not-be-rendered',
            });
          }
          return http.Response('{"success":false}', 404);
        });
        final reservationRepository = ReservationRepository(
          authRepository: authRepository,
        );
        final paymentRepository = PaymentRepository(
          authRepository: authRepository,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: BookingDetailScreen(
              booking: Booking.fromJson(_unpaidBooking),
              repository: reservationRepository,
              paymentRepository: paymentRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('payment-mock-disclaimer')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('payment-simulate-button')),
          findsOneWidget,
        );
        expect(requested, ['GET /api/payments/config']);
        expect(find.byKey(const ValueKey('booking-qr-load')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('payment-simulate-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('payment-simulate-confirm')),
          findsOneWidget,
        );
        expect(requested, ['GET /api/payments/config']);

        await tester.tap(
          find.byKey(const ValueKey('payment-simulate-confirm')),
        );
        await tester.pumpAndSettle();

        expect(requested, [
          'GET /api/payments/config',
          'GET /api/payments/config',
          'POST /api/payments/initiate',
          'POST /api/payments/payment-1/confirm-mock',
          'GET /api/payments/payment-1',
          'GET /api/reservations/my-reservations',
        ]);
        expect(find.text('Payé'), findsOneWidget);
        expect(find.byKey(const ValueKey('booking-qr-load')), findsOneWidget);
        expect(requested.where((path) => path.endsWith('/qr')), isEmpty);

        await tester.tap(find.byKey(const ValueKey('booking-qr-load')));
        await tester.pumpAndSettle();

        expect(requested.last, 'GET /api/reservations/reservation-1/qr');
        expect(find.byKey(const ValueKey('booking-qr-image')), findsOneWidget);
        final qrBackground = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('booking-qr-background')),
        );
        expect(qrBackground.color, Colors.white);
        expect(find.text('raw-qr-token-must-not-be-rendered'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'sandbox and unavailable configuration never enable Mock payment',
      (tester) async {
        final requested = <String>[];
        final authRepository = _authRepository((request) async {
          requested.add(request.url.path);
          if (request.url.path == '/api/payments/config') {
            return _success({'mode': 'sandbox'});
          }
          return http.Response('{"success":false}', 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BookingDetailScreen(
              key: const ValueKey('sandbox-payment-screen'),
              booking: Booking.fromJson(_unpaidBooking),
              repository: ReservationRepository(authRepository: authRepository),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('payment-sandbox-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('payment-simulate-button')),
          findsNothing,
        );
        expect(requested, ['/api/payments/config']);

        final unavailableAuth = _authRepository(
          (_) async => http.Response('{"success":false}', 503),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BookingDetailScreen(
              key: const ValueKey('unavailable-payment-screen'),
              booking: Booking.fromJson(_unpaidBooking),
              repository: ReservationRepository(
                authRepository: unavailableAuth,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('payment-config-error')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('payment-config-retry')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('payment-simulate-button')),
          findsNothing,
        );

        final unknownModeAuth = _authRepository(
          (_) async => _success({'mode': 'unexpected'}),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BookingDetailScreen(
              key: const ValueKey('unknown-payment-screen'),
              booking: Booking.fromJson(_unpaidBooking),
              repository: ReservationRepository(
                authRepository: unknownModeAuth,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('payment-mode-unknown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('payment-simulate-button')),
          findsNothing,
        );
      },
    );

    testWidgets('stops if mode changes before initiating payment', (
      tester,
    ) async {
      var configCalls = 0;
      final requested = <String>[];
      final authRepository = _authRepository((request) async {
        requested.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/payments/config') {
          configCalls++;
          return _success({'mode': configCalls == 1 ? 'mock' : 'sandbox'});
        }
        return http.Response('{"success":false}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingDetailScreen(
            booking: Booking.fromJson(_unpaidBooking),
            repository: ReservationRepository(authRepository: authRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-simulate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-simulate-confirm')));
      await tester.pumpAndSettle();

      expect(requested, [
        'GET /api/payments/config',
        'GET /api/payments/config',
      ]);
      expect(find.byKey(const ValueKey('payment-error')), findsOneWidget);
      expect(find.textContaining('mode de paiement a changé'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('payment-simulate-button')),
        findsNothing,
      );
    });

    testWidgets('does not expose payment actions for an already-paid booking', (
      tester,
    ) async {
      final requested = <String>[];
      final authRepository = _authRepository((request) async {
        requested.add(request.url.path);
        return _success({'qrCode': _qrDataUrl, 'token': 'raw-qr-token'});
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingDetailScreen(
            booking: Booking.fromJson(_paidBooking),
            repository: ReservationRepository(authRepository: authRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('payment-simulate-button')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('booking-qr-load')), findsOneWidget);
      expect(requested, isEmpty);

      await tester.tap(find.byKey(const ValueKey('booking-qr-load')));
      await tester.pumpAndSettle();

      expect(requested, ['/api/reservations/reservation-1/qr']);
      expect(find.byKey(const ValueKey('booking-qr-image')), findsOneWidget);
      expect(find.text('raw-qr-token'), findsNothing);
    });

    testWidgets('prevents a second confirmation while the first is pending', (
      tester,
    ) async {
      final confirmResponse = Completer<http.Response>();
      final confirmationStarted = Completer<void>();
      var confirmCount = 0;
      final authRepository = _authRepository((request) async {
        if (request.url.path == '/api/payments/config') {
          return _success({'mode': 'mock'});
        }
        if (request.url.path == '/api/payments/initiate') {
          return _success({
            'paymentId': 'payment-1',
            'mode': 'mock',
            'status': 'pending',
          }, statusCode: 201);
        }
        if (request.url.path == '/api/payments/payment-1/confirm-mock') {
          confirmCount++;
          if (!confirmationStarted.isCompleted) confirmationStarted.complete();
          return confirmResponse.future;
        }
        if (request.url.path == '/api/payments/payment-1') {
          return _success({
            'paymentId': 'payment-1',
            'reservationId': 'reservation-1',
            'mode': 'mock',
            'status': 'paid',
          });
        }
        if (request.url.path == '/api/reservations/my-reservations') {
          return http.Response(
            jsonEncode({
              'success': true,
              'count': 1,
              'data': [_paidBooking],
            }),
            200,
          );
        }
        return http.Response('{"success":false}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingDetailScreen(
            booking: Booking.fromJson(_unpaidBooking),
            repository: ReservationRepository(authRepository: authRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-simulate-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-simulate-confirm')));
      for (
        var attempt = 0;
        attempt < 10 && !confirmationStarted.isCompleted;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(confirmationStarted.isCompleted, isTrue);
      expect(confirmCount, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('payment-simulate-button')),
            )
            .onPressed,
        isNull,
      );

      confirmResponse.complete(
        _success({'paymentId': 'payment-1', 'status': 'paid'}),
      );
      await tester.pumpAndSettle();
      expect(confirmCount, 1);
    });
  });
}
