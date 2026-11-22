import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:myfirstflutterp/core/network/auth_repository.dart';
import 'package:myfirstflutterp/core/theme/app_theme.dart';
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

ReservationRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ReservationRepository(
    authRepository: AuthRepository(
      client: MockClient(handler),
      tokenStore: _TokenStore(),
    ),
  );
}

const _reservation = {
  'reservationId': 'reservation-1',
  'offerId': 'offer-1',
  'offerName': 'Offre test',
  'shopName': 'Commerce test',
  'quantity': 2,
  'unitPrice': 3.5,
  'totalPrice': 7,
  'status': 'pending',
  'paymentStatus': 'unpaid',
  'createdAt': {'_seconds': 1795280000, '_nanoseconds': 0},
};

const _reservationResponse =
    '{"success":true,"data":{"reservationId":"reservation-1","offerId":"offer-1","offerName":"Offre test","shopName":"Commerce test","quantity":2,"unitPrice":3.5,"totalPrice":7,"status":"pending","paymentStatus":"unpaid"}}';

void main() {
  test('loads and maps all reservation statuses and payment status', () async {
    late http.Request request;
    final items = [
      _reservation,
      {..._reservation, 'reservationId': 'confirmed', 'status': 'confirmed'},
      {..._reservation, 'reservationId': 'rejected', 'status': 'rejected'},
      {..._reservation, 'reservationId': 'cancelled', 'status': 'cancelled'},
      {..._reservation, 'reservationId': 'completed', 'status': 'completed'},
    ];
    final repository = _repository((sent) async {
      request = sent;
      return http.Response(
        jsonEncode({'success': true, 'count': items.length, 'data': items}),
        200,
      );
    });

    final bookings = await repository.fetchMyReservations();

    expect(bookings, hasLength(5));
    expect(bookings.map((booking) => booking.parsedStatus), [
      ReservationStatus.pending,
      ReservationStatus.confirmed,
      ReservationStatus.rejected,
      ReservationStatus.cancelled,
      ReservationStatus.completed,
    ]);
    expect(bookings.first.paymentStatusLabel, 'Non payé');
    expect(bookings.first.totalPrice, 7);
    expect(bookings.first.createdAt, isNotNull);
    expect(request.url.path, '/api/reservations/my-reservations');
    expect(request.headers['Authorization'], 'Bearer test-id-token');
  });

  test('returns an empty list for an empty backend response', () async {
    final repository = _repository(
      (_) async => http.Response('{"success":true,"count":0,"data":[]}', 200),
    );

    expect(await repository.fetchMyReservations(), isEmpty);
  });

  test(
    'posts the real offer ID and quantity and maps HTTP 201 response',
    () async {
      late http.Request request;
      final repository = _repository((sent) async {
        request = sent;
        return http.Response(_reservationResponse, 201);
      });

      final booking = await repository.createReservation(
        offerId: 'offer-1',
        quantity: 2,
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/reservations');
      expect(request.headers['Authorization'], 'Bearer test-id-token');
      expect(jsonDecode(request.body), {'offerId': 'offer-1', 'quantity': 2});
      expect(booking.id, 'reservation-1');
      expect(booking.status, 'pending');
      expect(booking.paymentStatus, 'unpaid');
    },
  );

  test('surfaces insufficient stock without creating a reservation', () async {
    var requestCount = 0;
    final repository = _repository((_) async {
      requestCount++;
      return http.Response(
        '{"success":false,"message":"Not enough offer quantity available."}',
        400,
      );
    });

    await expectLater(
      repository.createReservation(offerId: 'offer-1', quantity: 8),
      throwsA(
        isA<ReservationException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              contains('Not enough offer quantity'),
            ),
      ),
    );
    expect(requestCount, 1);
  });

  test(
    'maps successful cancellation and refuses backend-denied cancellation',
    () async {
      late http.Request request;
      final allowedRepository = _repository((sent) async {
        request = sent;
        return http.Response(
          '{"success":true,"data":{"reservationId":"reservation-1","offerId":"offer-1","offerName":"Offre test","quantity":2,"unitPrice":3.5,"totalPrice":7,"status":"cancelled","paymentStatus":"unpaid"}}',
          200,
        );
      });
      final cancelled = await allowedRepository.cancelReservation(
        'reservation-1',
      );
      expect(cancelled.parsedStatus, ReservationStatus.cancelled);
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/reservations/reservation-1/cancel');

      final refusedRepository = _repository(
        (_) async => http.Response(
          '{"success":false,"message":"Cannot cancel a reservation while payment is in progress or paid."}',
          400,
        ),
      );
      await expectLater(
        refusedRepository.cancelReservation('reservation-1'),
        throwsA(
          isA<ReservationException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.message,
                'message',
                contains('Cannot cancel'),
              ),
        ),
      );
    },
  );

  test(
    'allows cancellation only for pending unpaid or failed reservations',
    () {
      expect(Booking.fromJson(_reservation).canCancel, isTrue);
      expect(
        Booking.fromJson({..._reservation, 'paymentStatus': 'processing'})
            .canCancel,
        isFalse,
      );
      expect(
        Booking.fromJson({..._reservation, 'status': 'confirmed'}).canCancel,
        isFalse,
      );
    },
  );

  test('reports network errors as retryable', () async {
    final repository = _repository((_) async {
      throw const SocketException('offline');
    });

    await expectLater(
      repository.fetchMyReservations(),
      throwsA(
        isA<ReservationException>().having(
          (error) => error.retryable,
          'retryable',
          isTrue,
        ),
      ),
    );
  });

  test('preserves authorization errors from the backend', () async {
    final repository = _repository(
      (_) async =>
          http.Response('{"success":false,"message":"Access denied."}', 403),
    );

    await expectLater(
      repository.fetchMyReservations(),
      throwsA(
        isA<ReservationException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              'Tu n’es pas autorisé à effectuer cette action.',
            ),
      ),
    );
  });

  testWidgets('unpaid reservation has no QR action or generated code', (
    tester,
  ) async {
    final requestedPaths = <String>[];
    final repository = _repository((request) async {
      requestedPaths.add(request.url.path);
      return http.Response(
        '{"success":false,"message":"Reservation must be paid before generating QR Code."}',
        400,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BookingDetailScreen(
          booking: Booking.fromJson(_reservation),
          repository: repository,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('booking-qr-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('booking-qr-load')), findsNothing);
    expect(find.byKey(const ValueKey('booking-qr-image')), findsNothing);
    expect(find.byKey(const ValueKey('booking-cancel-button')), findsOneWidget);
    expect(requestedPaths, ['/api/payments/config']);
  });

  test('QR endpoint rejects an unpaid reservation response', () async {
    final repository = _repository(
      (_) async => http.Response(
        '{"success":false,"message":"Reservation must be paid before generating QR Code."}',
        400,
      ),
    );

    await expectLater(
      repository.fetchQr('reservation-1'),
      throwsA(
        isA<ReservationException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              contains('must be paid'),
            ),
      ),
    );
  });
}
