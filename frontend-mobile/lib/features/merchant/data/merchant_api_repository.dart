import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/auth_repository.dart';
import '../../search/models/shop_offer.dart';
import '../models/merchant_dashboard_stats.dart';
import '../models/merchant_order.dart';
import '../models/merchant_shop.dart';

class MerchantApiRepository {
  const MerchantApiRepository(this.authRepository);

  final AuthRepository authRepository;

  Future<MerchantShop?> getShop() async {
    try {
      return _read<MerchantShop>(
        await authRepository.getAuthenticated('/api/shops/my-shop'),
        _parseShop,
      );
    } on AuthException catch (error) {
      if (error.statusCode == 404 &&
          error.message == 'You have not registered a shop yet.') {
        return null;
      }
      rethrow;
    }
  }

  Future<MerchantShop> saveShop({
    required String name,
    required String address,
    required String phone,
    required String email,
    required String description,
    double? latitude,
    double? longitude,
    bool edit = false,
  }) async {
    final body = {
      'name': name,
      'address': address,
      'phone': phone,
      if (email.isNotEmpty) 'email': email,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
      'description': description,
    };
    final response = edit
        ? await authRepository.putAuthenticated('/api/shops/my-shop', body)
        : await authRepository.postAuthenticated('/api/shops/register', body);
    return _read(response, _parseShop);
  }

  Future<List<ShopOffer>> getOffers() async {
    final response = await authRepository.getAuthenticated(
      '/api/offers/merchant/my-offers',
    );
    return _read(response, (data) {
      if (data is! List) throw const FormatException();
      return data.map(_parseOffer).toList(growable: false);
    });
  }

  Future<ShopOffer> saveOffer(
    Map<String, Object> fields, {
    String? offerId,
  }) async {
    final response = offerId == null
        ? await authRepository.postAuthenticated('/api/offers', fields)
        : await authRepository.putAuthenticated(
            '/api/offers/${Uri.encodeComponent(offerId)}',
            fields,
          );
    return _read(response, _parseOffer);
  }

  Future<List<MerchantOrder>> getReservations() async {
    final response = await authRepository.getAuthenticated(
      '/api/reservations/merchant',
    );
    return _read(response, (data) {
      if (data is! List) throw const FormatException();
      return data
          .map((item) => MerchantOrder.fromJson(_object(item)))
          .toList(growable: false)
        ..sort((first, second) {
          final byDate = (second.createdAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(first.createdAt?.millisecondsSinceEpoch ?? 0);
          return byDate == 0 ? first.id.compareTo(second.id) : byDate;
        });
    });
  }

  Future<void> updateReservationStatus(
    String reservationId,
    MerchantOrderAction action,
  ) async {
    final status = switch (action) {
      MerchantOrderAction.confirm => 'confirmed',
      MerchantOrderAction.reject => 'rejected',
    };
    try {
      final response = await authRepository.putAuthenticated(
        '/api/reservations/${Uri.encodeComponent(reservationId)}/status',
        {'status': status},
      );
      _read<void>(response, (data) {
        final reservation = _object(data);
        if (reservation['reservationId'] != reservationId ||
            reservation['status'] != status) {
          throw const FormatException();
        }
      });
    } on AuthException catch (error) {
      final message = switch (error.statusCode) {
        400 => switch (error.message) {
          'Reservation must be paid before confirmation.' =>
            'Le paiement doit être effectué avant de confirmer.',
          'Cannot reject a reservation while payment is in progress or paid.' => 'Impossible de refuser cette réservation : paiement en cours ou effectué.',
          'Only pending reservations can be confirmed.' ||
          'Only pending reservations can be rejected.' =>
            'Seules les réservations en attente peuvent être modifiées.',
          _ => 'La réservation ne peut pas être modifiée dans son état actuel.',
        },
        403 => 'L’action n’est pas autorisée pour ce compte ou ce commerce.',
        404 =>
          'La réservation, le commerce ou l’offre associée est introuvable.',
        409 => 'L’état de la réservation a changé. Actualise la liste avant de réessayer.',
        _ => null,
      };
      if (message == null) rethrow;
      throw AuthException(message, statusCode: error.statusCode);
    }
  }

  Future<MerchantDashboardStats> getDashboard() async {
    final response = await authRepository.getAuthenticated(
      '/api/dashboard/merchant',
    );
    return _read(
      response,
      (data) => MerchantDashboardStats.fromJson(_object(data)),
    );
  }

  Future<String> verifyPickup(String token) async {
    try {
      final response = await authRepository.postAuthenticated(
        '/api/reservations/verify-qr',
        {'token': token},
      );
      return _read<String>(response, (data) {
        final result = _object(data);
        final id = result['reservationId'];
        if (id is! String ||
            id.trim().isEmpty ||
            result['status'] != 'completed' ||
            result['paymentStatus'] != 'paid') {
          throw const FormatException();
        }
        return id;
      });
    } on AuthException catch (error) {
      final message = switch (error.statusCode) {
        400 || 409 => switch (error.message) {
          'Invalid QR Code.' => 'Ce code QR est invalide.',
          'Invalid or expired QR Code.' => 'Ce code QR est invalide ou expiré.',
          'QR Code has already been used.' => 'Ce code QR a déjà été utilisé.',
          'Reservation is not paid.' => 'La réservation doit être payée.',
          'Only confirmed reservations can be completed.' =>
            'La réservation doit être confirmée avant le retrait.',
          _ => 'Ce code QR ne permet pas de valider le retrait.',
        },
        403 => 'Ce retrait n’est pas autorisé pour ton commerce.',
        404 => 'La réservation ou le commerce associé est introuvable.',
        401 || 500 || null => error.message,
        _ => 'Impossible de vérifier le retrait. Réessaie plus tard.',
      };
      throw AuthException(
        message,
        statusCode: error.statusCode,
        retryable: error.retryable,
      );
    }
  }

  static Map<String, dynamic> _object(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException();
    return json;
  }

  static MerchantShop _parseShop(Object? json) =>
      MerchantShop.fromJson(_object(json));

  static ShopOffer _parseOffer(Object? json) =>
      ShopOffer.fromJson(_object(json));

  T _read<T>(http.Response response, T Function(Object?) parse) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['success'] != true) {
        throw const FormatException();
      }
      return parse(body['data']);
    } on FormatException {
      throw const AuthException('Réponse invalide du serveur.');
    }
  }
}
