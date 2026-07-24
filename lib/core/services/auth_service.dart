import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/core/services/connectivity_service.dart';
import 'package:easy_split/core/services/local_cache_service.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';

/// Auth session service — manages token storage, caching, and auth state stream.
class AuthSessionService {
  final FlutterSecureStorage _storage;
  final ApiService _api;
  final ConnectivityService _connectivity;
  final LocalCacheService _cache;
  final _authStateController = StreamController<User?>.broadcast();

  User? _currentUser;

  AuthSessionService({
    FlutterSecureStorage? storage,
    required ApiService api,
    ConnectivityService? connectivity,
    LocalCacheService? cache,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _api = api,
        _connectivity = connectivity ?? ConnectivityService(),
        _cache = cache ?? LocalCacheService();

  /// Stream that emits auth state changes (login / logout).
  Stream<User?> get authStateChanges => _authStateController.stream;

  /// The currently signed-in user.
  User? get currentUser => _currentUser;

  /// Attempt to restore session from secure storage or local cache when offline.
  Future<User?> restoreSession() async {
    final token = await _storage.read(key: AppConstants.authTokenKey);
    if (token == null) return null;

    final cachedUser = await _cache.getCachedUser();
    final isOnline = await _connectivity.checkConnected();

    if (!isOnline) {
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _authStateController.add(cachedUser);
        return cachedUser;
      }
      return null;
    }

    try {
      final data = await _api.get('/users/me');
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _cache.saveUser(user);
      _currentUser = user;
      _authStateController.add(user);
      return user;
    } on AppException catch (e) {
      if (e.type == AppExceptionType.unauthorized) {
        // Backend explicitly invalidated session (401)
        await clearSession();
        return null;
      }
      // Network error or backend offline — fallback to cached user without clearing session
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _authStateController.add(cachedUser);
        return cachedUser;
      }
      return null;
    } catch (_) {
      if (cachedUser != null) {
        _currentUser = cachedUser;
        _authStateController.add(cachedUser);
        return cachedUser;
      }
      return null;
    }
  }

  /// Persist token and user after successful login.
  Future<void> saveSession({required String token, required User user}) async {
    await _storage.write(key: AppConstants.authTokenKey, value: token);
    await _storage.write(key: AppConstants.userIdKey, value: user.id);
    await _cache.saveUser(user);
    _currentUser = user;
    _authStateController.add(user);
  }

  /// Update current user object (after profile update).
  void updateCurrentUser(User user) {
    _currentUser = user;
    _cache.saveUser(user);
    _authStateController.add(user);
  }

  /// Clear session (logout).
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.authTokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
    await _cache.clearUserCache();
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
