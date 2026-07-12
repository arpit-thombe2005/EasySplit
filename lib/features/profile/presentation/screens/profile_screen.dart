import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/version_control/presentation/providers/version_provider.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                Stack(
                  children: [
                    AppAvatar(
                      name: user?.name ?? user?.email ?? 'U',
                      avatarId: user?.avatarId,
                      radius: 44,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _showAvatarPicker(context, ref, user?.avatarId),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'Set your name',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.secondary),
                ),
              ],
            ),
          ),

          const Divider(),

          // Preferences section
          _SectionHeader(title: 'Preferences'),

          // Currency
          _SettingsTile(
            icon: Icons.currency_exchange_rounded,
            title: 'Currency',
            subtitle: user?.currency ?? 'INR',
            onTap: () => _showCurrencyPicker(context, ref),
          ),

          // Theme
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: themeMode == ThemeMode.light
                ? 'Light'
                : themeMode == ThemeMode.dark
                    ? 'Dark'
                    : 'System',
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),

          const Divider(),
          _SectionHeader(title: 'Account'),

          // Edit profile
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile Name',
            onTap: () => _showEditProfileSheet(context, ref, user?.name ?? ''),
          ),

          // Contact & Support
          _SettingsTile(
            icon: Icons.support_agent_rounded,
            title: 'Help & Support',
            subtitle: 'easysplit2026@gmail.com',
            onTap: () => _showSupportSheet(context),
          ),

          // Privacy
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _showPrivacyPolicySheet(context),
          ),

          // App Version
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: packageInfoAsync.when(
              data: (info) => 'Version ${info.version}',
              loading: () => 'Version ...',
              error: (_, __) => 'Version ${AppConstants.appVersion}',
            ),
            showChevron: false,
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context, ref),
          ),

          // Delete Account
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context, WidgetRef ref, String? currentAvatarId) {
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
                  final isSelected = preset['id'] == (currentAvatarId ?? 'avatar_1');
                  return GestureDetector(
                    onTap: () async {
                      await ref.read(authNotifierProvider.notifier).updateProfile(
                            avatarId: preset['id'] as String,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
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

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final currentCode = ref.read(currentUserProvider)?.currency ?? 'INR';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Currency', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ...AppConstants.currencies.map((c) => ListTile(
                leading: Text(
                  c['symbol']!,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                title: Text(c['name']!),
                subtitle: Text(c['code']!),
                trailing: c['code'] == currentCode
                    ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ref.read(authNotifierProvider.notifier).updateProfile(
                        currency: c['code'],
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              )),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Choose Theme', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            title: const Text('System Default'),
            trailing: current == ThemeMode.system
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.system;
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Light Mode'),
            trailing: current == ThemeMode.light
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Dark Mode'),
            trailing: current == ThemeMode.dark
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).updateProfile(
                        name: nameController.text.trim(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.emailLogin);
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion requested')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicySheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.privacy_tip_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text('Privacy Policy', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Last updated: June 2026', style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary)),
            const SizedBox(height: 20),
            _policySection(theme, cs, '1. Information We Collect',
                'EasySplit collects basic user profile information (such as your name, email address, preferred currency, and avatar selection) as well as group expense data and transaction records to enable shared bill calculation.'),
            _policySection(theme, cs, '2. Expense Privacy',
                'Your group expenses, member balances, and financial settlement records are kept strictly confidential and are accessible exclusively to authorized members of your specific groups.'),
            _policySection(theme, cs, '3. Data Security & Backup',
                'We implement industry-standard encryption protocols for data in transit and at rest. When group owners permanently finalize and delete a group, automated backup reports (.xlsx & .pdf) are securely emailed to members before permanent removal.'),
            _policySection(theme, cs, '4. Email Communications',
                'Your email address is utilized solely for essential service functions, including account authentication (verification OTPs), group invitations, and automated backup exports upon group deletion.'),
            _policySection(theme, cs, '5. Your Rights & Control',
                'You maintain full authority over your data. You may update your profile preferences, leave groups, or request permanent account deletion directly within the profile settings at any time.'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _policySection(ThemeData theme, ColorScheme cs, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const supportEmail = 'easysplit2026@gmail.com';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.support_agent_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Text('Help & Support', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('We are here to help you manage and split your group expenses smoothly.', style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary)),
            const SizedBox(height: 20),

            // Email Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('Official Support Email', style: theme.textTheme.labelMedium?.copyWith(color: cs.secondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    supportEmail,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Email Address'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: supportEmail));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support email copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Frequently Asked Questions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _faqTile(theme, cs, '📊 How do I export group reports?', 'Open any group details, tap the 3-dot menu (⋮) in the top right, and select "Export Expenses" for Excel or "Export PDF".'),
            _faqTile(theme, cs, '🔒 What does locking a group do?', 'Locking a group freezes all expense additions and settlements, making the group read-only until unlocked by the owner.'),
            _faqTile(theme, cs, '✉️ Automated email backups', 'When a group is deleted by the owner, automated final copies (.xlsx & .pdf) are sent to all members before deletion.'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _faqTile(ThemeData theme, ColorScheme cs, String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(a, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: showChevron ? const Icon(Icons.chevron_right_rounded, size: 20) : null,
      onTap: onTap,
    );
  }
}

/// Settings Screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).state =
                  v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ],
      ),
    );
  }
}
