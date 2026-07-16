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

            // Groups list (only show active groups where myBalance != 0)
            groupsAsync.when(
              data: (groups) {
                final activeGroups = groups.where((g) => g.myBalance.abs() > 0.01).toList();

                if (activeGroups.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: EmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'All settled up!',
                        subtitle: 'You have no active debts or pending balances in any group.',
                      ),
                    ),
                  );
                }

                final preview = activeGroups.take(5).toList();
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: preview.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => GroupCard(
                      group: preview[i],
                      currency: currency,
                      onTap: () => context.go(
                        AppRoutes.groupDetail.replaceAll(':groupId', preview[i].id),
                      ),
                    ),
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
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            net.abs().toCurrency(currencyCode: currency),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            net == 0
                ? 'Everything is settled'
                : (isPositive ? 'You are owed overall' : 'You owe overall'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: cs.onPrimary.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You owe',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      summary!.totalOwed.toCurrency(currencyCode: currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're owed",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      summary!.totalOwedTo.toCurrency(currencyCode: currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
