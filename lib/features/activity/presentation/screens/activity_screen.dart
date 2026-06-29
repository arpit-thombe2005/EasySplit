import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/core/theme/app_theme.dart';
import 'package:easy_split/core/utils/currency_formatter.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/shared/widgets/expense_card.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';
import 'package:easy_split/shared/widgets/loading_overlay.dart';
import 'package:easy_split/shared/widgets/avatar_widget.dart';

/// Activity Screen — timeline of expenses and settlements
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(settlementsNotifierProvider);
    final expensesAsync = ref.watch(userExpensesProvider);
    final user = ref.watch(currentUserProvider);
    final currency = user?.currency ?? 'INR';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final settlements = settlementsAsync.valueOrNull ?? [];
    final expenses = expensesAsync.valueOrNull ?? [];
    final isLoading = settlementsAsync.isLoading || expensesAsync.isLoading;

    if (isLoading && settlements.isEmpty && expenses.isEmpty) {
      return const Scaffold(body: InlineLoader());
    }

    if (settlements.isEmpty && expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: const EmptyState(
          icon: Icons.history_rounded,
          title: 'No activity yet',
          subtitle: 'Your expense and settlement history will appear here once you add an expense.',
        ),
      );
    }

    final pending = settlements.where((s) => s.status.toLowerCase() == 'pending').toList();
    final completed = settlements.where((s) => s.status.toLowerCase() == 'completed').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(settlementsNotifierProvider.notifier).refresh();
          ref.invalidate(userExpensesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              Text('Pending Settlements', style: theme.textTheme.titleSmall?.copyWith(color: cs.secondary)),
              const SizedBox(height: 12),
              ...pending.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SettlementCard(
                      settlement: e.value,
                      currency: currency,
                      currentUserId: user?.id ?? '',
                      isDark: isDark,
                      onSettle: () async {
                        await ref
                            .read(settlementsNotifierProvider.notifier)
                            .confirmPayment(e.value.id, groupId: e.value.groupId);
                      },
                    )
                        .animate(delay: Duration(milliseconds: e.key * 60))
                        .fadeIn(duration: 350.ms)
                        .slideX(begin: 0.05, duration: 350.ms),
                  )),
              const SizedBox(height: 20),
            ],
            if (expenses.isNotEmpty) ...[
              Text('Recent Expenses', style: theme.textTheme.titleSmall?.copyWith(color: cs.secondary)),
              const SizedBox(height: 12),
              ...expenses.map((exp) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExpenseCard(
                      expense: exp,
                      currentUserId: user?.id ?? '',
                      currency: currency,
                    ),
                  )),
              const SizedBox(height: 20),
            ],
            if (completed.isNotEmpty) ...[
              Text('Completed Settlements', style: theme.textTheme.titleSmall?.copyWith(color: cs.secondary)),
              const SizedBox(height: 12),
              ...completed.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SettlementCard(
                      settlement: s,
                      currency: currency,
                      currentUserId: user?.id ?? '',
                      isDark: isDark,
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettlementCard extends ConsumerWidget {
  final Settlement settlement;
  final String currency;
  final String currentUserId;
  final bool isDark;
  final VoidCallback? onSettle;

  const _SettlementCard({
    required this.settlement,
    required this.currency,
    required this.currentUserId,
    required this.isDark,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCompleted = settlement.status.toLowerCase() == 'completed';
    final isOwer = settlement.fromUser == currentUserId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(
                  name: isOwer
                      ? (settlement.toUserName ?? 'U')
                      : (settlement.fromUserName ?? 'U'),
                  avatarId: isOwer ? settlement.toUserAvatar : settlement.fromUserAvatar,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwer
                            ? 'You → ${settlement.toUserName ?? 'Someone'}'
                            : '${settlement.fromUserName ?? 'Someone'} → You',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settlement.settledAt != null
                            ? DateFormat('MMM d, yyyy').format(settlement.settledAt!)
                            : 'Pending',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      settlement.amount.toCurrency(currencyCode: currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isOwer
                            ? (isDark ? AppTheme.negativeBalanceDark : AppTheme.negativeBalance)
                            : (isDark ? AppTheme.positiveBalanceDark : AppTheme.positiveBalance),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.positiveBalance.withValues(alpha: 0.2)
                              : AppTheme.positiveBalanceBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Settled',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? AppTheme.positiveBalanceDark : AppTheme.positiveBalance,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (!isCompleted && onSettle != null && !isOwer) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSettle,
                  child: const Text('Confirm Received'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
