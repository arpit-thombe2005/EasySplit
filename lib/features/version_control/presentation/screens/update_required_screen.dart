import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/features/version_control/presentation/providers/version_provider.dart';

class UpdateRequiredScreen extends ConsumerStatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  ConsumerState<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  bool _isLaunching = false;

  Future<void> _launchUpdateUrl(String url) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }
    if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }

    final uri = Uri.parse(cleanUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionState = ref.watch(versionCheckProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: versionState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.read(versionCheckProvider.notifier).retryCheck(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Logo or Visual Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 72,
                        color: cs.primary,
                      ),
                    )
                        .animate()
                        .fade(duration: 600.ms)
                        .scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 40),
                    
                    // Title
                    Text(
                      'Update Required',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    )
                        .animate()
                        .fade(delay: 200.ms, duration: 500.ms)
                        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOut),
                    
                    const SizedBox(height: 16),
                    
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'A new update is available for EasySplit. To continue splitting expenses and managing groups with your friends, please update to the latest version.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    )
                        .animate()
                        .fade(delay: 300.ms, duration: 500.ms)
                        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOut),
                    
                    const Spacer(),
                    
                    // Update Button
                    ElevatedButton.icon(
                      onPressed: _isLaunching
                          ? null
                          : () => _launchUpdateUrl(data.updateUrl),
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.open_in_browser_rounded),
                      label: Text(_isLaunching ? 'Opening Website...' : 'Update Now'),
                    )
                        .animate()
                        .fade(delay: 450.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
                    
                    const SizedBox(height: 12),
                    
                    // Retry Button
                    TextButton(
                      onPressed: () => ref.read(versionCheckProvider.notifier).retryCheck(),
                      child: const Text('Try Again'),
                    )
                        .animate()
                        .fade(delay: 550.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
