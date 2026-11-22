class ProfileData {
  const ProfileData({
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.role,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      name: _optionalString(json['name']) ?? _optionalString(json['fullName']),
      email: _optionalString(json['email']),
      phone: _optionalString(json['phone']),
      photoUrl: _optionalString(json['photoURL']),
      role: _optionalString(json['role']),
    );
  }

  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? role;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
