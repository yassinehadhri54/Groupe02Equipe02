import 'dart:convert';

import '../../../core/network/auth_repository.dart';
import '../models/booking.dart';

class ReservationException implements Exception {
  const ReservationException(
    this.message, {
    this.statusCode,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

class ReservationQr {
  const ReservationQr({required this.imageDataUrl});

  final String imageDataUrl;

  factory ReservationQr.fromJson(Map<String, dynamic> json) {
    final imageDataUrl = json['qrCode'];
    if (imageDataUrl is! String || !imageDataUrl.startsWith('data:image/')) {
      throw const FormatException('QR image is missing.');
    }
    return ReservationQr(imageDataUrl: imageDataUrl);
  }
}

class ReservationRepository {
  const ReservationRepository({required this.authRepository});

  final AuthRepository authRepository;

  Future<List<Booking>> fetchMyReservations() async {
    try {
      final response = await authRepository.getAuthenticated(
        '/api/reservations/my-reservations',
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        throw const FormatException('Invalid reservation list.');
      }

      return (decoded['data'] as List).map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid reservation entry.');
        }
        return Booking.fromJson(item);
      }).toList();
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const ReservationException(
        'Les réservations reçues du serveur sont invalides.',
      );
    }
  }

  Future<Booking> createReservation({
    required String offerId,
    required int quantity,
  }) async {
    if (offerId.trim().isEmpty || quantity < 1) {
      throw const ReservationException(
        'Sélectionne une offre et une quantité valides.',
        statusCode: 400,
      );
    }

    try {
      final response = await authRepository.postAuthenticated(
        '/api/reservations',
        {'offerId': offerId, 'quantity': quantity},
      );
      if (response.statusCode != 201) {
        throw const ReservationException(
          'Le serveur n’a pas confirmé la création de la réservation.',
        );
      }
      return Booking.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const ReservationException(
        'La confirmation de réservation reçue du serveur est invalide.',
      );
    }
  }

  Future<Booking> cancelReservation(String reservationId) async {
    if (reservationId.trim().isEmpty) {
      throw const ReservationException('Identifiant de réservation manquant.');
    }

    try {
      final response = await authRepository.putAuthenticated(
        '/api/reservations/${Uri.encodeComponent(reservationId)}/cancel',
        const {},
      );
      return Booking.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const ReservationException(
        'La confirmation d’annulation reçue du serveur est invalide.',
      );
    }
  }

  Future<ReservationQr> fetchQr(String reservationId) async {
    if (reservationId.trim().isEmpty) {
      throw const ReservationException('Identifiant de réservation manquant.');
    }

    try {
      final response = await authRepository.getAuthenticated(
        '/api/reservations/${Uri.encodeComponent(reservationId)}/qr',
      );
      return ReservationQr.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const ReservationException('Le QR reçu du serveur est invalide.');
    }
  }

  Map<String, dynamic> _responseData(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid reservation response.');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  ReservationException _fromAuthException(AuthException error) {
    return ReservationException(
      error.message,
      statusCode: error.statusCode,
      retryable: error.retryable,
    );
  }
}
