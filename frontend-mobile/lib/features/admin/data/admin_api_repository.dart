import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/auth_repository.dart';
import '../../merchant/models/merchant_shop.dart';
import '../../search/models/shop_offer.dart';
import '../models/admin_data.dart';

class AdminApiRepository {
  const AdminApiRepository(
    this.authRepository, {
    required this.administratorId,
  });

  final AuthRepository authRepository;
  final String administratorId;

  Future<AdminStats> loadDashboard() async {
    final response = await authRepository.getAuthenticated(
      '/api/dashboard/admin',
    );
    return _decode(response, (json) {
      final data = json['data'];
      return data == null
          ? const AdminStats()
          : AdminStats.fromJson(_object(data));
    });
  }

  Future<List<ShopOffer>> loadOffers({
    String? query,
    String? category,
    String? status,
    bool? adminDisabled,
  }) async {
    final filters = {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (adminDisabled != null) 'adminDisabled': adminDisabled.toString(),
    };
    final path = Uri(
      path: '/api/admin/offers',
      queryParameters: filters.isEmpty ? null : filters,
    );
    final response = await authRepository.getAuthenticated(path.toString());
    return _decode(response, (json) => _list(json['data'], _offer));
  }

  Future<AdminOfferDetail> loadOffer(String id) async {
    final response = await authRepository.getAuthenticated(
      '/api/admin/offers/${Uri.encodeComponent(id)}',
    );
    return _decode(response, (json) {
      final detail = _object(json['data']);
      final offer = _offer(_object(detail['offer']));
      if (offer.id != id) throw const FormatException();
      final shopJson = detail['shop'];
      MerchantShop? shop;
      if (shopJson != null) {
        final fields = _object(shopJson);
        shop = MerchantShop.fromJson({
          ...fields,
          'status': fields['status'] ?? 'unknown',
        });
      }
      return (offer: offer, shop: shop);
    });
  }

  Future<void> moderateOffer(
    String id, {
    required bool adminDisabled,
    String? reason,
  }) async {
    final trimmed = reason?.trim();
    final response = await authRepository.putAuthenticated(
      '/api/admin/offers/${Uri.encodeComponent(id)}/moderation',
      {
        'adminDisabled': adminDisabled,
        if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
      },
    );
    _decode<void>(response, (json) {
      final data = _object(json['data']);
      if (data['id'] != id || data['adminDisabled'] != adminDisabled) {
        throw const FormatException();
      }
    });
  }

  static ShopOffer _offer(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) throw const FormatException();
    final name = json['name'];
    return ShopOffer.fromJson({
      ...json,
      'offerId': id,
      'name': name is String && name.trim().isNotEmpty
          ? name
          : 'Offre sans nom',
    });
  }

  Future<List<AdminShop>> loadShops({String? status}) async {
    final query = status == null
        ? ''
        : '?status=${Uri.encodeQueryComponent(status)}';
    final response = await authRepository.getAuthenticated('/api/shops$query');
    return _decode(response, (json) => _list(json['data'], AdminShop.fromJson));
  }

  Future<void> updateShop(AdminShop entry, AdminShopAction action) async {
    if (!entry.allows(action)) {
      throw const AuthException(
        'Cette décision n’est pas disponible pour ce commerce.',
        statusCode: 400,
      );
    }
    final id = entry.shop.id;
    final response = await authRepository.putAuthenticated(
      '/api/shops/${Uri.encodeComponent(id)}/${action.name}',
      {},
    );
    _decode<void>(response, (json) {
      final data = _object(json['data']);
      final expected = action == AdminShopAction.approve
          ? 'approved'
          : 'rejected';
      if (data['shopId'] != id || data['status'] != expected) {
        throw const FormatException();
      }
    });
  }

  Future<List<AdminUser>> loadUsers() async {
    final response = await authRepository.getAuthenticated('/api/users');
    return _decode(
      response,
      (json) => _list(json['users'], AdminUser.fromJson),
    );
  }

  Future<AdminUser> loadUser(String uid) async {
    final response = await authRepository.getAuthenticated(
      '/api/users/${Uri.encodeComponent(uid)}',
    );
    return _decode(response, (json) => _user(json, uid));
  }

  Future<AdminUser> updateUser(AdminUser user, AdminUserAction action) async {
    if (user.availableAction(administratorId) != action) {
      throw const AuthException(
        'Cette opération est interdite pour ce compte.',
        statusCode: 400,
      );
    }
    final response = await authRepository.putAuthenticated(
      '/api/users/${Uri.encodeComponent(user.uid)}/status',
      {'status': action == AdminUserAction.suspend ? 'suspended' : 'active'},
    );
    return _decode(response, (json) => _user(json, user.uid));
  }

  static AdminUser _user(Map<String, dynamic> json, String uid) {
    final user = AdminUser.fromJson(_object(json['user']));
    if (user.uid != uid) throw const FormatException();
    return user;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException();
  }

  static List<T> _list<T>(
    Object? data,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (data is! List) throw const FormatException();
    return data.map((item) => parse(_object(item))).toList(growable: false);
  }

  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      final json = _object(jsonDecode(utf8.decode(response.bodyBytes)));
      if (json['success'] != true) throw const FormatException();
      return parse(json);
    } on FormatException {
      throw const AuthException('Réponse administrateur invalide.');
    }
  }
}
