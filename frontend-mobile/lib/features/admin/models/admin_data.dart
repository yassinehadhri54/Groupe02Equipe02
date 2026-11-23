import '../../merchant/models/merchant_shop.dart';
import '../../profile/models/profile_data.dart';
import '../../search/models/shop_offer.dart';

typedef AdminOfferDetail = ({ShopOffer offer, MerchantShop? shop});

enum AdminShopAction { approve, reject }

enum AdminUserAction { suspend, reactivate }

const adminShopStatuses = ['pending', 'approved', 'rejected', 'suspended'];
const adminUserStatuses = ['active', 'pending', 'rejected', 'suspended'];
const adminRoles = ['student', 'merchant', 'admin'];

String adminStatusLabel(String? status) => switch (status) {
  'active' => 'Actif',
  'pending' => 'En attente',
  'approved' => 'Approuvé',
  'rejected' => 'Refusé',
  'suspended' => 'Suspendu',
  final value? when value.isNotEmpty => value,
  _ => 'Indisponible',
};

String adminRoleLabel(String? role) => switch (role) {
  'student' => 'Étudiant',
  'merchant' => 'Commerçant',
  'admin' => 'Administrateur',
  _ => 'Rôle inconnu',
};

class AdminStats {
  const AdminStats({
    this.users,
    this.shops,
    this.pendingShops,
    this.offers,
    this.reservations,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    int? readCount(String group, {String? status}) {
      final section = json[group];
      if (section == null) return null;
      if (section is! Map<String, dynamic>) throw const FormatException();
      final totals = status == null ? section : section['byStatus'];
      if (totals == null) return null;
      if (totals is! Map<String, dynamic>) throw const FormatException();
      final value = totals[status ?? 'total'];
      if (value == null) return null;
      if (value is! int || value < 0) throw const FormatException();
      return value;
    }

    return AdminStats(
      users: readCount('users'),
      shops: readCount('shops'),
      pendingShops: readCount('shops', status: 'pending'),
      offers: readCount('offers'),
      reservations: readCount('reservations'),
    );
  }

  final int? users;
  final int? shops;
  final int? pendingShops;
  final int? offers;
  final int? reservations;
}

class AdminShop {
  const AdminShop({required this.shop, this.ownerName, this.ownerEmail});

  factory AdminShop.fromJson(Map<String, dynamic> json) => AdminShop(
    shop: MerchantShop.fromJson({
      ...json,
      'shopId': json['id'] ?? json['shopId'],
    }),
    ownerName: _text(json['ownerName']),
    ownerEmail: _text(json['ownerEmail']),
  );

  final MerchantShop shop;
  final String? ownerName;
  final String? ownerEmail;

  bool allows(AdminShopAction action) => switch (action) {
    AdminShopAction.approve => const {
      'pending',
      'rejected',
    }.contains(shop.status),
    AdminShopAction.reject => const {
      'pending',
      'approved',
    }.contains(shop.status),
  };
}

class AdminUser {
  const AdminUser({required this.uid, required this.profile, this.status});

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final uid = _text(json['uid']);
    if (uid == null) throw const FormatException();
    return AdminUser(
      uid: uid,
      profile: ProfileData.fromJson(json),
      status: _text(json['status']),
    );
  }

  final String uid;
  final ProfileData profile;
  final String? status;
  String get displayName => profile.name ?? profile.email ?? uid;

  AdminUserAction? availableAction(String administratorId) {
    if (uid == administratorId ||
        !const {'student', 'merchant'}.contains(profile.role)) {
      return null;
    }
    return switch (status) {
      'suspended' => AdminUserAction.reactivate,
      'active' || 'pending' || 'rejected' => AdminUserAction.suspend,
      _ => null,
    };
  }
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
