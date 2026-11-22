import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, this.retryable = false});

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }

  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String status;
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.idToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String idToken;
  final String refreshToken;
}

abstract interface class AuthTokenStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthRepository {
  AuthRepository({
    http.Client? client,
    AuthTokenStore? tokenStore,
    this._baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5000',
    ),
  }) : _client = client ?? http.Client(),
       _tokenStore = tokenStore ?? SecureAuthTokenStore();

  final http.Client _client;
  final String _baseUrl;
  final AuthTokenStore _tokenStore;

  static const _legacySessionKey = 'campussave_auth_session';
  static const _userKey = 'campussave_auth_user';
  static const _idTokenKey = 'campussave_id_token';
  static const _refreshTokenKey = 'campussave_refresh_token';

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await _tokenStore.write(_idTokenKey, session.idToken);
    await _tokenStore.write(_refreshTokenKey, session.refreshToken);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'uid': session.user.uid,
        'email': session.user.email,
        'fullName': session.user.fullName,
        'role': session.user.role,
        'status': session.user.status,
      }),
    );
    await prefs.remove(_legacySessionKey);
  }

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final idToken = await _tokenStore.read(_idTokenKey);
    final refreshToken = await _tokenStore.read(_refreshTokenKey);
    final rawUser = prefs.getString(_userKey);

    if (idToken != null && refreshToken != null && rawUser != null) {
      final user = AuthUser.fromJson(
        jsonDecode(rawUser) as Map<String, dynamic>,
      );
      return AuthSession(
        user: user,
        idToken: idToken,
        refreshToken: refreshToken,
      );
    }

    final legacy = prefs.getString(_legacySessionKey);
    if (legacy == null) return null;

    try {
      final data = jsonDecode(legacy) as Map<String, dynamic>;
      final session = AuthSession(
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        idToken: data['idToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      await saveSession(session);
      return session;
    } catch (_) {
      await prefs.remove(_legacySessionKey);
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _tokenStore.delete(_idTokenKey);
    await _tokenStore.delete(_refreshTokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_legacySessionKey);
  }

  Future<AuthSession> restoreValidatedSession() async {
    final session = await loadSession();
    if (session == null) {
      throw const AuthException('Aucune session enregistrée.');
    }

    final response = await _get('/api/auth/me', session.idToken);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final validated = AuthSession(
      user: user,
      idToken: session.idToken,
      refreshToken: session.refreshToken,
    );
    await saveSession(validated);
    return validated;
  }

  Future<http.Response> _get(String path, String idToken) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearSession();
        throw const AuthException('Votre session a expiré. Reconnectez-vous.');
      }

      throw const AuthException('Impossible de vérifier votre session.');
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Impossible de vérifier la session. Vérifiez la connexion au serveur.',
      );
    }
  }

  Future<http.Response> getAuthenticated(String path) {
    return _authenticatedRequest(
      (idToken) => _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<http.Response> getPublic(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final requestUri = queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);

    try {
      final response = await _client
          .get(requestUri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      if (response.statusCode >= 500) {
        throw AuthException(
          'Le serveur rencontre un problème. Réessaie plus tard.',
          statusCode: response.statusCode,
          retryable: true,
        );
      }

      throw AuthException(
        _messageFromResponse(response) ??
            'La requête a échoué (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on AuthException {
      rethrow;
    } on FormatException {
      throw const AuthException('Réponse invalide du serveur.');
    } catch (_) {
      throw const AuthException(
        'Impossible de contacter le serveur. Vérifie ta connexion puis réessaie.',
        retryable: true,
      );
    }
  }

  Future<http.Response> postAuthenticated(
    String path,
    Map<String, dynamic> body,
  ) {
    return _authenticatedRequest(
      (idToken) => _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<http.Response> putAuthenticated(
    String path,
    Map<String, dynamic> body,
  ) {
    return _authenticatedRequest(
      (idToken) => _client
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(String idToken) send,
  ) async {
    final idToken = await _tokenStore.read(_idTokenKey);
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'Aucune session active. Reconnecte-toi.',
        statusCode: 401,
      );
    }

    try {
      final response = await send(idToken);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      if (response.statusCode == 401) {
        await clearSession();
        throw const AuthException(
          'Ta session a expiré. Reconnecte-toi.',
          statusCode: 401,
        );
      }

      if (response.statusCode == 403) {
        throw const AuthException(
          'Tu n’es pas autorisé à effectuer cette action.',
          statusCode: 403,
        );
      }

      if (response.statusCode >= 500) {
        throw AuthException(
          'Le serveur rencontre un problème. Réessaie plus tard.',
          statusCode: response.statusCode,
          retryable: true,
        );
      }

      throw AuthException(
        _messageFromResponse(response) ??
            'La requête a échoué (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on AuthException {
      rethrow;
    } on FormatException {
      throw const AuthException('Réponse invalide du serveur.');
    } catch (_) {
      throw const AuthException(
        'Impossible de contacter le serveur. Vérifie ta connexion puis réessaie.',
        retryable: true,
      );
    }
  }

  String? _messageFromResponse(http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = data['tokens'] as Map<String, dynamic>;

    return AuthSession(
      user: user,
      idToken: tokens['idToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/register', {
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': 'student',
    }, diagnoseRegistration: true);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    bool diagnoseRegistration = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    int? statusCode;

    void logDiagnostic({required String outcome, String? exceptionType}) {
      if (!diagnoseRegistration || !kDebugMode) return;

      final exception = exceptionType == null
          ? ''
          : ' exceptionType=$exceptionType';
      debugPrint(
        '[AuthRepository.register] outcome=$outcome '
        'durationMs=${stopwatch.elapsedMilliseconds} '
        'httpStatus=${statusCode ?? 'none'}$exception',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      statusCode = response.statusCode;
      final data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        logDiagnostic(outcome: 'response');
        return response;
      }

      throw AuthException(
        _errorMessage(response.statusCode, data['message'] as String?),
        statusCode: response.statusCode,
      );
    } on AuthException catch (error) {
      logDiagnostic(
        outcome: 'http_error',
        exceptionType: error.runtimeType.toString(),
      );
      rethrow;
    } on FormatException catch (error) {
      logDiagnostic(
        outcome: 'invalid_response',
        exceptionType: error.runtimeType.toString(),
      );
      throw const AuthException('Réponse invalide du serveur.');
    } catch (error) {
      logDiagnostic(
        outcome: 'exception',
        exceptionType: error.runtimeType.toString(),
      );
      throw const AuthException(
        'Impossible de contacter le serveur. Vérifie ta connexion puis réessaie.',
        retryable: true,
      );
    }
  }

  String _errorMessage(int statusCode, String? message) {
    if (statusCode == 409) {
      return 'Cette adresse e-mail est déjà utilisée.';
    }

    if (statusCode >= 500) {
      return 'Une erreur serveur est survenue. Réessaie plus tard.';
    }

    if (statusCode == 400) {
      switch (message) {
        case 'All fields are required.':
          return 'Tous les champs sont obligatoires.';
        case 'Invalid email format.':
          return 'Saisis une adresse e-mail valide.';
        case 'Password must contain at least 8 characters.':
          return 'Le mot de passe doit contenir au moins 8 caractères.';
        case 'Invalid role.':
          return 'Le rôle demandé est invalide.';
        case 'Invalid email or password.':
          return 'L’adresse e-mail ou le mot de passe est invalide.';
      }
    }

    return message ?? 'Le serveur a retourné une erreur ($statusCode).';
  }
}
