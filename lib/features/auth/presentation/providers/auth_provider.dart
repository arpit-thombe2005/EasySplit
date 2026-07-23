import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/core/services/auth_service.dart';
import 'package:easy_split/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';
import 'package:easy_split/features/auth/domain/repositories/auth_repository.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/core/services/push_notification_service.dart';

// ── Infrastructure Providers ──────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiService(storage: storage);
});

final authSessionProvider = Provider<AuthSessionService>((ref) {
  final api = ref.watch(apiServiceProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthSessionService(api: api, storage: storage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.watch(apiServiceProvider),
    session: ref.watch(authSessionProvider),
  );
});

// ── Auth State ────────────────────────────────────────────────────

/// Notifier managing OTP flow state
class AuthNotifier extends AsyncNotifier<User?> {
  void _clearUserSessionState() {
    ref.invalidate(groupsNotifierProvider);
    ref.invalidate(pendingInvitationsProvider);
    ref.invalidate(settlementsNotifierProvider);
  }

  @override
  Future<User?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    return repo.getCurrentUser();
  }

  Future<void> sendOtp(String email) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.sendOtp(email);
  }

  Future<bool> verifyOtp({required String email, required String otp}) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.verifyOtp(email: email, otp: otp);
      _clearUserSessionState();
      final user = await repo.getCurrentUser();
      state = AsyncData(user);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> completeProfile({
    required String name,
    String? avatarId,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.completeProfile(
      name: name,
      avatarId: avatarId,
    );
    state = AsyncData(user);
  }

  Future<void> updateProfile({
    String? name,
    String? avatarId,
    String? currency,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.updateProfile(
      name: name,
      avatarId: avatarId,
      currency: currency,
    );
    state = AsyncData(user);

    // Invalidate cached providers to fetch fresh profile data (avatar, name, currency, etc.)
    ref.invalidate(groupsNotifierProvider);
    ref.invalidate(settlementsNotifierProvider);
    ref.invalidate(userExpensesProvider);

    final groups = ref.read(groupsNotifierProvider).valueOrNull ?? [];
    for (final group in groups) {
      ref.invalidate(groupDetailProvider(group.id));
    }
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      try {
        await ref.read(pushNotificationServiceProvider).deleteToken();
      } catch (e) {
        if (kDebugMode) print('Failed to delete FCM token on logout: $e');
      }
    }

    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    _clearUserSessionState();
    state = const AsyncData(null);
  }

  Future<bool> deleteAccount() async {
    try {
      if (!kIsWeb) {
        try {
          await ref.read(pushNotificationServiceProvider).deleteToken();
        } catch (e) {
          if (kDebugMode) print('Failed to delete FCM token on account deletion: $e');
        }
      }

      final repo = ref.read(authRepositoryProvider);
      await repo.deleteAccount();
      _clearUserSessionState();
      state = const AsyncData(null);
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to delete account: $e');
      return false;
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

/// Convenience: is the user logged in?
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.valueOrNull != null;
});

/// Convenience: get current user (non-null when authenticated)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authNotifierProvider).valueOrNull;
});

// ── OTP Form State ─────────────────────────────────────────────────

class OtpFormState {
  final String email;
  final bool isLoading;
  final bool otpSent;
  final String? error;

  const OtpFormState({
    this.email = '',
    this.isLoading = false,
    this.otpSent = false,
    this.error,
  });

  OtpFormState copyWith({
    String? email,
    bool? isLoading,
    bool? otpSent,
    String? error,
    bool clearError = false,
  }) =>
      OtpFormState(
        email: email ?? this.email,
        isLoading: isLoading ?? this.isLoading,
        otpSent: otpSent ?? this.otpSent,
        error: clearError ? null : (error ?? this.error),
      );
}

class OtpFormNotifier extends Notifier<OtpFormState> {
  @override
  OtpFormState build() => const OtpFormState();

  Future<void> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authNotifierProvider.notifier).sendOtp(email);
      state = state.copyWith(email: email, isLoading: false, otpSent: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .verifyOtp(email: state.email, otp: otp);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() => state = const OtpFormState();
}

final otpFormProvider = NotifierProvider<OtpFormNotifier, OtpFormState>(
  OtpFormNotifier.new,
);
