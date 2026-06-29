import 'package:flutter/material.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/core/utils/currency_formatter.dart';
import 'package:easy_split/core/theme/app_theme.dart';

/// Card widget for displaying a group in a list.
class GroupCard extends StatelessWidget {
  final Group group;
  final String currency;
  final VoidCallback? onTap;

  const GroupCard({
    super.key,
    required this.group,
    this.currency = 'INR',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isOwed = group.myBalance >= 0;
    final balanceColor = isOwed
        ? (isDark ? AppTheme.positiveBalanceDark : AppTheme.positiveBalance)
        : (isDark ? AppTheme.negativeBalanceDark : AppTheme.negativeBalance);
    final balanceBg = isOwed
        ? (isDark ? AppTheme.positiveBalance.withValues(alpha: 0.15) : AppTheme.positiveBalanceBg)
        : (isDark ? AppTheme.negativeBalance.withValues(alpha: 0.15) : AppTheme.negativeBalanceBg);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Group avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty
                        ? group.name[0].toUpperCase()
                        : 'G',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.members.length} member${group.members.length != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.secondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Balance badge
              if (group.myBalance != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: balanceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group.myBalance.abs().toCurrency(currencyCode: currency),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'settled',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
