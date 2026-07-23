import 'package:flutter/material.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/core/utils/currency_formatter.dart';
import 'package:easy_split/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Card widget for displaying an expense in a list.
class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currentUserId;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.currentUserId,
    this.currency = 'INR',
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOwed = expense.paidBy == currentUserId;
    final canManage = expense.paidBy == currentUserId && (onEdit != null || onDelete != null);

    // Calculate current user's share
    final myShare = expense.participants
        .where((p) => p.userId == currentUserId)
        .fold<double>(0, (s, p) => s + p.shareAmount);

    final balanceColor = isOwed
        ? Theme.of(context).brightness == Brightness.light
            ? AppTheme.positiveBalance
            : AppTheme.positiveBalanceDark
        : Theme.of(context).brightness == Brightness.light
            ? AppTheme.negativeBalance
            : AppTheme.negativeBalanceDark;

    return Card(
      child: InkWell(
        onTap: onTap ?? (canManage ? () => _showManageSheet(context) : null),
        onLongPress: canManage ? () => _showManageSheet(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(expense.category),
                  size: 22,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 12),

              // Title and meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.paidByUser?.name ?? 'Someone'} paid '
                      '${expense.amount.toCurrency(currencyCode: currency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(expense.expenseDate ?? expense.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOwed ? 'you lent' : 'you owe',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.secondary,
                    ),
                  ),
                  Text(
                    isOwed
                        ? (expense.amount - myShare)
                            .toCurrency(currencyCode: currency)
                        : myShare.toCurrency(currencyCode: currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  expense.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${expense.paidByUser?.name ?? 'Someone'} paid ${expense.amount.toCurrency(currencyCode: currency)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const Divider(),
              if (onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Expense'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                  title: Text('Delete Expense', style: TextStyle(color: cs.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & drink': return Icons.restaurant_rounded;
      case 'transport': return Icons.directions_car_rounded;
      case 'accommodation': return Icons.hotel_rounded;
      case 'entertainment': return Icons.movie_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'utilities': return Icons.bolt_rounded;
      case 'healthcare': return Icons.medical_services_rounded;
      case 'travel': return Icons.flight_rounded;
      case 'education': return Icons.school_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
