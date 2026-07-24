import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/shared/widgets/app_button.dart';
import 'package:easy_split/shared/widgets/app_text_field.dart';

import 'package:easy_split/core/services/connectivity_service.dart';

/// Email Login Screen
/// Matches Stitch design: minimal, black/white, professional
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (ref.read(isOfflineProvider)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Internet connection required to sign in.')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    await ref.read(otpFormProvider.notifier).sendOtp(_emailController.text);
    final state = ref.read(otpFormProvider);
    if (state.otpSent && mounted) {
      context.push(AppRoutes.otpVerify);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpFormProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOffline) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Internet connection required to sign in.',
                              style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 48),

                  // Logo / App name
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.jpeg',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, duration: 400.ms),

                  const SizedBox(height: 56),

                  // Heading
                  Text(
                    'Sign in to your\naccount',
                    style: theme.textTheme.headlineLarge,
                  )
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, duration: 400.ms),

                  const SizedBox(height: 8),
                  Text(
                    "We'll send a verification code to your email.",
                    style: theme.textTheme.bodyLarge?.copyWith(color: cs.secondary),
                  )
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 40),

                  // Email field
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendOtp(),
                    prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter your email';
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(val)) return 'Enter a valid email';
                      return null;
                    },
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, duration: 400.ms),

                  // Error message
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Send OTP button
                  AppButton(
                    label: 'Continue with Email',
                    onPressed: _sendOtp,
                    isLoading: state.isLoading,
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
