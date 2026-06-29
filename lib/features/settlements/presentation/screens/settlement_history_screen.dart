import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';

/// Screen displaying complete Settlement History and pending receiver confirmations.
class SettlementHistoryScreen extends ConsumerWidget {
  const SettlementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';
    final settlementsAsync = ref.watch(settlementsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement History'),
      ),
      body: settlementsAsync.when(
        data: (settlements) {
          if (settlements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: cs.secondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No settlements recorded yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Completed and pending payments will appear here.', style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(settlementsNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: settlements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = settlements[i];
                final isPayer = s.fromUser == currentUserId;
                final isReceiver = s.toUser == currentUserId;
                final isPending = s.status.toLowerCase() == 'pending';
                final isCompleted = s.status.toLowerCase() == 'completed';
                final isRejected = s.status.toLowerCase() == 'rejected';

                final otherName = isPayer ? (s.toUserName ?? 'Member') : (s.fromUserName ?? 'Member');
                final actionTitle = isPayer ? 'You paid $otherName' : '$otherName paid You';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primary,
                                child: Icon(
                                  isPayer ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: cs.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    actionTitle,
                                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${s.paymentMethod} • ${_formatDate(s.createdAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.secondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '₹${s.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? (isPayer ? cs.error : Colors.green) : cs.onSurface,
                            ),
                          ),
                        ],
                      ),

                      if (s.note != null && s.note!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Note: ${s.note}',
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: cs.secondary),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? cs.primary
                                  : (isRejected ? cs.errorContainer : cs.surfaceContainerHigh),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              s.status.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isCompleted ? cs.onPrimary : (isRejected ? cs.onErrorContainer : cs.onSurface),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Receiver Confirmation Action Buttons
                          if (isPending && isReceiver)
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => ref.read(settlementsNotifierProvider.notifier).rejectPayment(s.id, groupId: s.groupId),
                                  style: TextButton.styleFrom(foregroundColor: cs.error),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => ref.read(settlementsNotifierProvider.notifier).confirmPayment(s.id, groupId: s.groupId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                  ),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settlement history: $e')),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
