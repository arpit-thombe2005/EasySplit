import 'dart:async';
import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/core/services/auth_service.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';
import 'package:easy_split/features/auth/domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository] using the REST API.
class AuthRepositoryImpl implements AuthRepository {
  final ApiService _api;
  final AuthSessionService _session;

  AuthRepositoryImpl({
    required ApiService api,
    required AuthSessionService session,
  })  : _api = api,
        _session = session;

  @override
  Future<void> sendOtp(String email) async {
    await _api.post('/auth/send-otp', data: {'email': email.toLowerCase().trim()});
  }

  @override
  Future<String> verifyOtp({required String email, required String otp}) async {
    final data = await _api.post('/auth/verify-otp', data: {
      'email': email.toLowerCase().trim(),
      'otp': otp.trim(),
    });

    final token = data['token'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _session.saveSession(token: token, user: user);
    return token;
  }

  @override
  Future<User> completeProfile({
    required String name,
    String? avatarId,
  }) async {
    final responseData = await _api.patch('/users/me', data: {
      'name': name,
      if (avatarId != null) 'avatar_id': avatarId,
    });

    final user = User.fromJson(responseData['user'] as Map<String, dynamic>);
    _session.updateCurrentUser(user);
    return user;
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_session.currentUser != null) return _session.currentUser;
    return _session.restoreSession();
  }

  @override
  Future<User> updateProfile({
    String? name,
    String? avatarId,
    String? currency,
  }) async {
    final responseData = await _api.patch('/users/me', data: {
      if (name != null) 'name': name,
      if (avatarId != null) 'avatar_id': avatarId,
      if (currency != null) 'currency': currency,
    });

    final user = User.fromJson(responseData['user'] as Map<String, dynamic>);
    _session.updateCurrentUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Best-effort server logout
    } finally {
      await _session.clearSession();
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _api.delete('/users/me');
    } finally {
      await _session.clearSession();
    }
  }

  @override
  Future<bool> isAuthenticated() => _session.isAuthenticated();

  @override
  Stream<User?> get authStateChanges => _session.authStateChanges;
}
