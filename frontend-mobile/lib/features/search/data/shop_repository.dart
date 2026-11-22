import 'dart:convert';

import '../../../core/network/auth_repository.dart';
import '../models/shop_offer.dart';
import '../models/shop_summary.dart';

class ShopRepositoryException implements Exception {
  const ShopRepositoryException(
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

class ShopRepository {
  const ShopRepository({required this.authRepository});

  final AuthRepository authRepository;

  Future<List<ShopOffer>> fetchOffers({
    String? category,
    String? shopId,
    double? maxPrice,
    String? query,
    String? product,
    String? shop,
  }) {
    final queryParameters = <String, String>{
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (shopId != null && shopId.trim().isNotEmpty) 'shopId': shopId.trim(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (product != null && product.trim().isNotEmpty)
        'product': product.trim(),
      if (shop != null && shop.trim().isNotEmpty) 'shop': shop.trim(),
    };

    return _fetchOffers(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<ShopOffer> fetchOfferById(String id) async {
    if (id.trim().isEmpty) {
      throw const ShopRepositoryException(
        'Identifiant de l’offre manquant.',
      );
    }

    try {
      final response = await authRepository.getPublic(
        '/api/offers/${Uri.encodeComponent(id)}',
      );
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid offer response.');
      }

      return ShopOffer.fromJson(decoded['data'] as Map<String, dynamic>);
    } on AuthException catch (error) {
      throw ShopRepositoryException(
        error.message,
        statusCode: error.statusCode,
        retryable: error.retryable,
      );
    } on FormatException {
      throw const ShopRepositoryException(
        'Les détails de l’offre reçus du serveur sont invalides.',
      );
    }
  }

  Future<List<ShopSummary>> fetchShopsWithAvailableOffers() async {
    final offers = await fetchOffers();
    final offersByShop = <String, List<ShopOffer>>{};

    for (final offer in offers) {
      final shopId = offer.shopId;
      if (shopId != null) {
        offersByShop.putIfAbsent(shopId, () => []).add(offer);
      }
    }

    final shops = offersByShop.entries.map((entry) {
      final shopOffers = entry.value;
      final name = shopOffers
          .map((offer) => offer.shopName)
          .whereType<String>()
          .firstOrNull;
      final categories = shopOffers
          .map((offer) => offer.category)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();

      return ShopSummary(
        id: entry.key,
        name: name ?? '',
        categories: categories,
        availableOfferCount: shopOffers.length,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return shops;
  }

  Future<List<ShopOffer>> fetchOffersForShop(String shopId) {
    if (shopId.trim().isEmpty) {
      throw const ShopRepositoryException('Identifiant du commerce manquant.');
    }

    return fetchOffers(shopId: shopId);
  }

  Future<List<ShopOffer>> _fetchOffers({
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await authRepository.getPublic(
        '/api/offers',
        queryParameters: queryParameters,
      );
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        throw const FormatException('Invalid offers response.');
      }

      return (decoded['data'] as List).map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid offer entry.');
        }
        return ShopOffer.fromJson(item);
      }).toList();
    } on AuthException catch (error) {
      throw ShopRepositoryException(
        error.message,
        statusCode: error.statusCode,
        retryable: error.retryable,
      );
    } on FormatException {
      throw const ShopRepositoryException(
        'Les offres reçues du serveur sont invalides.',
      );
    }
  }
}
