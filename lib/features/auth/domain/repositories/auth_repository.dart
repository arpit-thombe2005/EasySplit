import 'package:easy_split/features/auth/domain/models/user.dart';

/// Abstract repository interface for authentication.
/// All auth operations go through this contract.
abstract class AuthRepository {
  /// Send OTP to the provided email address.
  Future<void> sendOtp(String email);

  /// Verify OTP for the given email. Returns JWT token on success.
  Future<String> verifyOtp({required String email, required String otp});

  /// Complete profile for a new user.
  Future<User> completeProfile({
    required String name,
    String? avatarId,
  });

  /// Get the currently authenticated user, or null if not logged in.
  Future<User?> getCurrentUser();

  /// Update user profile.
  Future<User> updateProfile({
    String? name,
    String? avatarId,
    String? currency,
  });

  /// Log out the current user and clear stored credentials.
  Future<void> logout();

  /// Check if the user is authenticated.
  Future<bool> isAuthenticated();

  /// Stream that emits when auth state changes (login/logout).
  Stream<User?> get authStateChanges;
}
