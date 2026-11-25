import 'dart:convert';

import '../../../core/network/auth_repository.dart';
import '../models/profile_data.dart';

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileRepository {
  const ProfileRepository({required this.authRepository});

  final AuthRepository authRepository;

  Future<ProfileData> fetchProfile() async {
    final response = await authRepository.getAuthenticated(
      '/api/users/profile',
    );

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['user'] is! Map<String, dynamic>) {
        throw const ProfileException(
          'Les données du profil reçues sont invalides.',
        );
      }

      return ProfileData.fromJson(decoded['user'] as Map<String, dynamic>);
    } on FormatException {
      throw const ProfileException(
        'Les données du profil reçues sont invalides.',
      );
    }
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    final body = <String, dynamic>{'name': name.trim()};
    if (phone != null) {
      body['phone'] = phone.trim();
    }

    await authRepository.putAuthenticated('/api/users/profile', body);
  }
}
