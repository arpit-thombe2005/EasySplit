import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/shared/widgets/app_button.dart';
import 'package:easy_split/shared/widgets/app_text_field.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';

/// Sign Up / Complete Profile Screen
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedAvatarId = 'avatar_1';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.avatarId != null) {
      _selectedAvatarId = user!.avatarId!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAvatarSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose your Avatar', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: AppConstants.avatarPresets.length,
                itemBuilder: (ctx, i) {
                  final preset = AppConstants.avatarPresets[i];
                  final isSelected = preset['id'] == _selectedAvatarId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatarId = preset['id'] as String);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                            : null,
                      ),
                      child: AppAvatar(
                        avatarId: preset['id'] as String,
                        name: preset['name'] as String,
                        radius: 26,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).completeProfile(
            name: _nameController.text.trim(),
            avatarId: _selectedAvatarId,
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                Text(
                  'Complete your\nprofile',
                  style: theme.textTheme.headlineLarge,
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, duration: 400.ms),

                const SizedBox(height: 8),
                Text(
                  'Tell us a bit about yourself to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: cs.secondary),
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 40),

                // Built-in avatar selector
                Center(
                  child: GestureDetector(
                    onTap: _showAvatarSelector,
                    child: Stack(
                      children: [
                        AppAvatar(
                          avatarId: _selectedAvatarId,
                          name: _nameController.text.isNotEmpty ? _nameController.text : 'User',
                          radius: 48,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8), duration: 400.ms),

                const SizedBox(height: 32),

                // Name field
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Your name',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _completeProfile(),
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter your name';
                    if (val.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, duration: 400.ms),

                const SizedBox(height: 24),

                AppButton(
                  label: 'Get Started',
                  onPressed: _completeProfile,
                  isLoading: _isLoading,
                )
                    .animate(delay: 250.ms)
                    .fadeIn(duration: 400.ms),

                const Spacer(),

                Center(
                  child: Text(
                    'You can update your avatar and details anytime.',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
