import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/auth/presentation/screens/email_login_screen.dart';
import 'package:easy_split/features/auth/presentation/screens/otp_screen.dart';
import 'package:easy_split/features/auth/presentation/screens/signup_screen.dart';
import 'package:easy_split/features/home/presentation/screens/home_screen.dart';
import 'package:easy_split/features/groups/presentation/screens/groups_screen.dart';
import 'package:easy_split/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:easy_split/features/activity/presentation/screens/activity_screen.dart';
import 'package:easy_split/features/profile/presentation/screens/profile_screen.dart';
import 'package:easy_split/features/groups/presentation/screens/group_invitations_screen.dart';
import 'package:easy_split/features/settlements/presentation/screens/settlement_history_screen.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';


/// Provides the GoRouter instance as a Riverpod provider.
/// Re-evaluates routes when auth state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // Still loading auth state — no redirect
      if (authState.isLoading) return null;

      final isAuthenticated = authState.valueOrNull != null;
      final loc = state.matchedLocation;

      // If not authenticated
      if (!isAuthenticated) {
        final allowedUnauthRoutes = [AppRoutes.emailLogin, AppRoutes.otpVerify];
        if (!allowedUnauthRoutes.contains(loc)) {
          return AppRoutes.emailLogin;
        }
        return null;
      }

      // If authenticated and on auth/splash route, send to home or signup
      final authRoutes = [
        AppRoutes.emailLogin,
        AppRoutes.otpVerify,
        AppRoutes.signUp,
        AppRoutes.splash,
      ];

      if (authRoutes.contains(loc)) {
        if (authState.valueOrNull?.name == null ||
            authState.valueOrNull!.name!.trim().isEmpty) {
          if (loc != AppRoutes.signUp) return AppRoutes.signUp;
          return null;
        }
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (ctx, state) => const _SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.emailLogin,
        builder: (ctx, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (ctx, state) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (ctx, state) => const SignUpScreen(),
      ),

      // ── Main Shell ────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, navigationShell) =>
            _MainShell(navigationShell: navigationShell),
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (ctx, state) => const HomeScreen(),
              ),
            ],
          ),

          // Groups
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (ctx, state) => const GroupsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (ctx, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: ':groupId',
                    builder: (ctx, state) => GroupDetailScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'expenses/add',
                        builder: (ctx, state) => AddExpenseScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Activity
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activity,
                builder: (ctx, state) => const ActivityScreen(),
              ),
            ],
          ),

          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (ctx, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (ctx, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Standalone Routes ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        builder: (ctx, state) => const _NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupInvitations,
        builder: (ctx, state) => const GroupInvitationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settlementHistory,
        builder: (ctx, state) => const SettlementHistoryScreen(),
      ),
    ],
  );
});

/// Bottom navigation shell with 4 tabs.
class _MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _MainShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Splash screen — shows while auth state is resolving.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.call_split_rounded, color: cs.onPrimary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notifications & Invitations Overview Screen
class _NotificationsScreen extends ConsumerWidget {
  const _NotificationsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingInvitationsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mail_outline_rounded, color: cs.onPrimary, size: 22),
              ),
              title: const Text('Group Invitations', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                pendingCount > 0
                    ? '$pendingCount pending invitation${pendingCount > 1 ? 's' : ''}'
                    : 'No pending invitations',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingCount > 0)
                    Badge(
                      label: Text('$pendingCount'),
                      backgroundColor: cs.primary,
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => context.push(AppRoutes.groupInvitations),
            ),
          ),
        ],
      ),
    );
  }
}
