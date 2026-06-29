import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Settings',
          ),
        ],
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

          // Avatar Selector
          _SettingsTile(
            icon: Icons.face_rounded,
            title: 'Change Avatar',
            subtitle: 'Choose from collection',
            onTap: () => _showAvatarPicker(context, ref, user?.avatarId),
          ),

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

          // Privacy
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),

          // About
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About EasySplit',
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: () {},
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
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
