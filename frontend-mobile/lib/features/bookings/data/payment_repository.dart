import 'dart:convert';

import '../../../core/network/auth_repository.dart';

String? _stringValue(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

enum PaymentMode {
  mock,
  sandbox,
  unknown;

  static PaymentMode fromValue(Object? value) => switch (value) {
    'mock' => PaymentMode.mock,
    'sandbox' => PaymentMode.sandbox,
    _ => PaymentMode.unknown,
  };
}

class PaymentException implements Exception {
  const PaymentException(
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

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.mode,
    required this.status,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['paymentId']) ?? _stringValue(json['id']);
    final status = _stringValue(json['status']);
    if (id == null || status == null) {
      throw const FormatException('Required payment fields are missing.');
    }

    return PaymentRecord(
      id: id,
      mode: PaymentMode.fromValue(json['mode']),
      status: status.toLowerCase(),
    );
  }

  final String id;
  final PaymentMode mode;
  final String status;
}

class PaymentRepository {
  const PaymentRepository({required this.authRepository});

  final AuthRepository authRepository;

  Future<PaymentMode> fetchMode() async {
    try {
      final response = await authRepository.getAuthenticated(
        '/api/payments/config',
      );
      final data = _responseData(response.body);
      return PaymentMode.fromValue(data['mode']);
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const PaymentException(
        'La configuration du paiement reçue du serveur est invalide.',
      );
    }
  }

  Future<PaymentRecord> initiatePayment(String reservationId) async {
    if (reservationId.trim().isEmpty) {
      throw const PaymentException('Identifiant de réservation manquant.');
    }

    try {
      final response = await authRepository.postAuthenticated(
        '/api/payments/initiate',
        {'reservationId': reservationId},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const PaymentException(
          'Le serveur n’a pas confirmé l’initialisation du paiement.',
        );
      }
      return PaymentRecord.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const PaymentException(
        'La réponse d’initialisation du paiement est invalide.',
      );
    }
  }

  Future<PaymentRecord> confirmMockPayment(String paymentId) async {
    if (paymentId.trim().isEmpty) {
      throw const PaymentException('Identifiant de paiement manquant.');
    }

    try {
      final response = await authRepository.postAuthenticated(
        '/api/payments/${Uri.encodeComponent(paymentId)}/confirm-mock',
        const {},
      );
      if (response.statusCode != 200) {
        throw const PaymentException(
          'Le serveur n’a pas confirmé le paiement de démonstration.',
        );
      }
      return PaymentRecord.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const PaymentException(
        'La confirmation du paiement reçue du serveur est invalide.',
      );
    }
  }

  Future<PaymentRecord> fetchPayment(String paymentId) async {
    if (paymentId.trim().isEmpty) {
      throw const PaymentException('Identifiant de paiement manquant.');
    }

    try {
      final response = await authRepository.getAuthenticated(
        '/api/payments/${Uri.encodeComponent(paymentId)}',
      );
      return PaymentRecord.fromJson(_responseData(response.body));
    } on AuthException catch (error) {
      throw _fromAuthException(error);
    } on FormatException {
      throw const PaymentException(
        'Le statut du paiement reçu du serveur est invalide.',
      );
    }
  }

  Map<String, dynamic> _responseData(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment response.');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  PaymentException _fromAuthException(AuthException error) {
    return PaymentException(
      error.message,
      statusCode: error.statusCode,
      retryable: error.retryable,
    );
  }
}
