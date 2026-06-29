import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';

/// Auth session service — manages token storage and auth state stream.
class AuthSessionService {
  final FlutterSecureStorage _storage;
  final ApiService _api;
  final _authStateController = StreamController<User?>.broadcast();

  User? _currentUser;

  AuthSessionService({
    FlutterSecureStorage? storage,
    required ApiService api,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _api = api;

  /// Stream that emits auth state changes (login / logout).
  Stream<User?> get authStateChanges => _authStateController.stream;

  /// The currently signed-in user.
  User? get currentUser => _currentUser;

  /// Attempt to restore session from secure storage.
  Future<User?> restoreSession() async {
    final token = await _storage.read(key: AppConstants.authTokenKey);
    if (token == null) return null;

    try {
      final data = await _api.get('/users/me');
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      _currentUser = user;
      _authStateController.add(user);
      return user;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  /// Persist token and user after successful login.
  Future<void> saveSession({required String token, required User user}) async {
    await _storage.write(key: AppConstants.authTokenKey, value: token);
    await _storage.write(key: AppConstants.userIdKey, value: user.id);
    _currentUser = user;
    _authStateController.add(user);
  }

  /// Update current user object (after profile update).
  void updateCurrentUser(User user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  /// Clear session (logout).
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.authTokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Check if authenticated.
  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: AppConstants.authTokenKey);
    return token != null;
  }

  void dispose() {
    _authStateController.close();
  }
}
