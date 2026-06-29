import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/shared/widgets/loading_overlay.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';

class GroupAnalyticsScreen extends ConsumerWidget {
  final String groupId;

  const GroupAnalyticsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final currencySymbol = (user?.currency ?? 'INR') == 'INR' ? '₹' : (user?.currency ?? '₹');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final analyticsAsync = ref.watch(
      groupAnalyticsProvider((groupId: groupId, filter: 'all', startDate: null, endDate: null)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: analyticsAsync.when(
        data: (data) {
          final overview = data['overview'] as Map<String, dynamic>? ?? {};
          final memberSpending = (data['memberSpending'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final memberBalances = (data['memberBalances'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          final totalExpenses = ((overview['totalExpenses'] ?? 0) as num).toDouble();
          
          // Find my split (my share) from memberBalances
          double mySplit = 0.0;
          if (user != null && memberBalances.isNotEmpty) {
            final myStat = memberBalances.firstWhere(
              (m) => (m['userId'] as String? ?? '').toLowerCase() == user.id.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (myStat.isNotEmpty && myStat.containsKey('totalShare')) {
              mySplit = ((myStat['totalShare'] ?? 0) as num).toDouble();
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Summary Cards (Total Group Expense & My Split) ───────────────
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      theme,
                      cs,
                      'Total Group Expense',
                      '$currencySymbol${totalExpenses.toStringAsFixed(2)}',
                      Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      theme,
                      cs,
                      'My Split',
                      '$currencySymbol${mySplit.toStringAsFixed(2)}',
                      Icons.pie_chart_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Member Spending Pie Chart ────────────────────────────────────
              Text(
                'Member Spending',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildMemberSpendingPieChart(theme, cs, memberSpending, currencySymbol),
            ],
          );
        },
        loading: () => const Center(child: InlineLoader()),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load statistics',
            subtitle: e.toString(),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(ThemeData theme, ColorScheme cs, String title, String value, IconData icon) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: cs.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSpendingPieChart(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No member spending data'),
        ),
      );
    }

    const colors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF10B981), // Emerald Green
      Color(0xFFF59E0B), // Amber / Orange
      Color(0xFFEC4899), // Rose / Pink
      Color(0xFF3B82F6), // Electric Blue
      Color(0xFF8B5CF6), // Purple
      Color(0xFF14B8A6), // Teal
      Color(0xFFF97316), // Bright Orange
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(items.length, (i) {
                  final item = items[i];
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: (item['amount'] as num).toDouble(),
                    title: '${item['percentage']}%',
                    radius: 50.0,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(item['userName'] as String, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(
                      '$symbol${(item['amount'] as num).toStringAsFixed(2)} (${item['percentage']}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
