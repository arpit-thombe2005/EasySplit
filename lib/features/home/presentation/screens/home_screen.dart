import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/utils/currency_formatter.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';
import 'package:easy_split/shared/widgets/group_card.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';

/// Home Dashboard Screen
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final groupsAsync = ref.watch(groupsNotifierProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = user?.currency ?? 'INR';
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupsNotifierProvider);
          ref.invalidate(settlementsNotifierProvider);
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              title: Text(
                AppConstants.appName,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              actions: [
                // Notifications
                Consumer(
                  builder: (context, ref, _) {
                    final pendingAsync = ref.watch(pendingInvitationsProvider);
                    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;
                    return IconButton(
                      icon: pendingCount > 0
                          ? Badge(
                              label: Text('$pendingCount'),
                              child: const Icon(Icons.notifications_outlined, size: 24),
                            )
                          : const Icon(Icons.notifications_outlined, size: 24),
                      onPressed: () => context.push(AppRoutes.notifications),
                      tooltip: 'Notifications',
                    );
                  },
                ),
                // Profile avatar
                GestureDetector(
                  onTap: () => context.push(AppRoutes.profile),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, left: 4),
                    child: AppAvatar(
                      name: user?.name ?? user?.email ?? 'U',
                      avatarId: user?.avatarId,
                      radius: 18,
                    ),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      'Hey, ${user?.name?.split(' ').first ?? 'there'} 👋',
                      style: theme.textTheme.headlineSmall,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, duration: 400.ms),
                    const SizedBox(height: 4),
                    Text(
                      "Here's your expense overview",
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.secondary),
                    )
                        .animate(delay: 50.ms)
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    // Balance Summary Card
                    _BalanceSummaryCard(
                      summary: summary,
                      currency: currency,
                      isDark: isDark,
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 28),

                    // Quick Actions
                    _QuickActions().animate(delay: 200.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: 28),

                    // Groups section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Groups', style: theme.textTheme.titleMedium),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.groups),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Groups list
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.group_outlined,
                      title: 'No groups yet',
                      subtitle: 'Create a group to start splitting expenses with friends.',
                      actionLabel: 'Create Group',
                      onAction: () => context.push(AppRoutes.createGroup),
                    ),
                  );
                }
                // Show top 5 groups on home
                final preview = groups.take(5).toList();
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: preview.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => GroupCard(
                      group: preview[i],
                      currency: currency,
                      onTap: () => context.push(
                        AppRoutes.groupDetail.replaceAll(':groupId', preview[i].id),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 300 + i * 50))
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: 0.05, duration: 400.ms),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SkeletonCard(),
                      ),
                    ),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Failed to load groups.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  final DashboardSummary? summary;
  final String currency;
  final bool isDark;

  const _BalanceSummaryCard({
    this.summary,
    this.currency = 'INR',
    this.isDark = false,
  });

  const _BalanceSummaryCard.skeleton()
      : summary = null,
        currency = 'INR',
        isDark = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (summary == null) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    final net = summary!.netBalance;
    final isPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Balance',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            net.abs().toCurrency(currencyCode: currency),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isPositive
                ? 'You are owed overall'
                : 'You owe overall',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryItem(
                label: 'You owe',
                amount: summary!.totalOwed.toCurrency(currencyCode: currency),
                color: cs.onPrimary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 24),
              _SummaryItem(
                label: 'You\'re owed',
                amount: summary!.totalOwedTo.toCurrency(currencyCode: currency),
                color: cs.onPrimary.withValues(alpha: 0.85),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onPrimary.withValues(alpha: 0.6),
          ),
        ),
        Text(
          amount,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionItem(
          icon: Icons.add_rounded,
          label: 'Add Expense',
          onTap: () {
            // Navigates to groups first to select context
            context.go(AppRoutes.groups);
          },
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon: Icons.group_add_outlined,
          label: 'New Group',
          onTap: () => context.push(AppRoutes.createGroup),
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon: Icons.sync_alt_rounded,
          label: 'Settle Up',
          onTap: () => context.go(AppRoutes.activity),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
