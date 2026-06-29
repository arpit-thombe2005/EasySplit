import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/core/services/auth_service.dart';
import 'package:easy_split/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';
import 'package:easy_split/features/auth/domain/repositories/auth_repository.dart';

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
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
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
        error: e.toString().replaceAll('AppException(server): ', ''),
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
        error: e.toString().replaceAll('AppException(server): ', ''),
      );
      return false;
    }
  }

  void reset() => state = const OtpFormState();
}

final otpFormProvider = NotifierProvider<OtpFormNotifier, OtpFormState>(
  OtpFormNotifier.new,
);
