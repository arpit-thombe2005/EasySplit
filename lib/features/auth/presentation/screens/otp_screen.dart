import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/shared/widgets/app_button.dart';
import 'package:easy_split/shared/widgets/app_text_field.dart';

/// OTP Verification Screen
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _secondsLeft = AppConstants.otpResendCooldown;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _secondsLeft = AppConstants.otpResendCooldown;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != AppConstants.otpLength) return;

    final success =
        await ref.read(otpFormProvider.notifier).verifyOtp(otp);

    if (!mounted) return;
    if (success) {
      final user = ref.read(authNotifierProvider).valueOrNull;
      // If new user (no name), go to sign up / complete profile
      if (user?.name == null || user!.name!.isEmpty) {
        context.go(AppRoutes.signUp);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final email = ref.read(otpFormProvider).email;
    await ref.read(otpFormProvider.notifier).sendOtp(email);
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpFormProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.mark_email_read_outlined, size: 28, color: cs.primary),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 400.ms),

              const SizedBox(height: 24),

              Text(
                'Check your\nemail',
                style: theme.textTheme.headlineLarge,
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(color: cs.secondary),
                  children: [
                    const TextSpan(text: "We sent a 6-digit code to\n"),
                    TextSpan(
                      text: state.email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: 150.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              // OTP input
              OtpTextField(
                controller: _otpController,
                onChanged: (v) {
                  if (v.length == AppConstants.otpLength) _verifyOtp();
                },
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms),

              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],

              const SizedBox(height: 24),

              AppButton(
                label: 'Verify Code',
                onPressed: _verifyOtp,
                isLoading: state.isLoading,
              )
                  .animate(delay: 250.ms)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // Resend
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resendOtp,
                        child: const Text('Resend Code'),
                      )
                    : Text(
                        'Resend code in ${_secondsLeft}s',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.secondary,
                        ),
                      ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
