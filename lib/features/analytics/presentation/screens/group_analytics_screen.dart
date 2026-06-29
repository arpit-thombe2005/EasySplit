import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/shared/widgets/loading_overlay.dart';
import 'package:easy_split/shared/widgets/empty_state.dart';

class GroupAnalyticsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAnalyticsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupAnalyticsScreen> createState() => _GroupAnalyticsScreenState();
}

class _GroupAnalyticsScreenState extends ConsumerState<GroupAnalyticsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currencySymbol = (user?.currency ?? 'INR') == 'INR' ? '₹' : (user?.currency ?? '₹');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final analyticsAsync = ref.watch(
      groupAnalyticsProvider((groupId: widget.groupId, filter: _selectedFilter, startDate: null, endDate: null)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: analyticsAsync.when(
        data: (data) {
          final overview = data['overview'] as Map<String, dynamic>? ?? {};
          final settlementProgress = data['settlementProgress'] as Map<String, dynamic>? ?? {};
          final categoryDistribution = (data['categoryDistribution'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final memberSpending = (data['memberSpending'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final memberBalances = (data['memberBalances'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final monthlyTrend = (data['monthlyTrend'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final categoryBreakdown = (data['categoryBreakdown'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final topStats = data['topStatistics'] as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Filter Chips ────────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All Time'),
                    const SizedBox(width: 8),
                    _filterChip('this_week', 'This Week'),
                    const SizedBox(width: 8),
                    _filterChip('this_month', 'This Month'),
                    const SizedBox(width: 8),
                    _filterChip('last_month', 'Last Month'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Settlement Progress Card ─────────────────────────────────────
              _buildSettlementProgressCard(theme, cs, settlementProgress, currencySymbol),
              const SizedBox(height: 20),

              // ── Overview Grid ───────────────────────────────────────────────
              Text('Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _metricCard(theme, cs, 'Total Expenses', '$currencySymbol${(overview['totalExpenses'] ?? 0).toStringAsFixed(2)}', Icons.payments_outlined),
                  _metricCard(theme, cs, 'Total Members', '${overview['totalMembers'] ?? 0}', Icons.people_outline),
                  _metricCard(theme, cs, 'Total Settlements', '${overview['totalSettlements'] ?? 0}', Icons.handshake_outlined),
                  _metricCard(theme, cs, 'Outstanding Balance', '$currencySymbol${(overview['outstandingBalance'] ?? 0).toStringAsFixed(2)}', Icons.account_balance_wallet_outlined),
                  _metricCard(theme, cs, 'Total Transactions', '${overview['totalTransactions'] ?? 0}', Icons.receipt_long_outlined),
                  _metricCard(theme, cs, 'Group Lifetime', '${overview['groupLifetimeDays'] ?? 0} days', Icons.calendar_today_outlined),
                ],
              ),
              const SizedBox(height: 24),

              // ── Expense Distribution (Pie Chart by Category) ─────────────────
              Text('Expense by Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildCategoryPieChart(theme, cs, categoryDistribution, currencySymbol),
              const SizedBox(height: 24),

              // ── Member Spending (Pie Chart by Member Paid) ───────────────────
              Text('Member Spending', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildMemberSpendingPieChart(theme, cs, memberSpending, currencySymbol),
              const SizedBox(height: 24),

              // ── Member Balance Horizontal Bars ───────────────────────────────
              Text('Member Balances', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildMemberBalancesSection(theme, cs, memberBalances, currencySymbol),
              const SizedBox(height: 24),

              // ── Monthly Spending Trend Line Chart ────────────────────────────
              if (monthlyTrend.isNotEmpty) ...[
                Text('Monthly Spending Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildMonthlyTrendChart(theme, cs, monthlyTrend, currencySymbol),
                const SizedBox(height: 24),
              ],

              // ── Category Breakdown ───────────────────────────────────────────
              Text('Category Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildCategoryBreakdownList(theme, cs, categoryBreakdown, currencySymbol),
              const SizedBox(height: 24),

              // ── Top Statistics Cards ─────────────────────────────────────────
              Text('Top Highlights', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTopStatisticsGrid(theme, cs, topStats, currencySymbol),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: InlineLoader()),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load statistics',
            subtitle: e.toString().replaceAll('AppException(server): ', ''),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimary : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _metricCard(ThemeData theme, ColorScheme cs, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(icon, size: 16, color: cs.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSettlementProgressCard(ThemeData theme, ColorScheme cs, Map<String, dynamic> data, String symbol) {
    final isSettled = data['isFullySettled'] == true;
    final progress = ((data['progressPercentage'] ?? 0) as num).toDouble() / 100.0;

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
              Text('Settlement Progress', style: theme.textTheme.titleSmall?.copyWith(color: cs.secondary)),
              if (isSettled)
                const Text('🎉 Group Fully Settled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
              else
                Text('${(progress * 100).toInt()}% Settled', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              color: isSettled ? Colors.green : cs.primary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subStat('Outstanding', '$symbol${(data['totalOutstanding'] ?? 0).toStringAsFixed(2)}', theme, cs),
              _subStat('Settled', '$symbol${(data['totalSettled'] ?? 0).toStringAsFixed(2)}', theme, cs),
              _subStat('Remaining', '$symbol${(data['remaining'] ?? 0).toStringAsFixed(2)}', theme, cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subStat(String label, String val, ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary)),
        const SizedBox(height: 2),
        Text(val, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCategoryPieChart(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No expense distribution data')));

    final colors = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      Colors.blueGrey,
      Colors.grey,
      Colors.black87,
      Colors.black54,
      Colors.black38,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: List.generate(items.length, (i) {
                  final item = items[i];
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: (item['amount'] as num).toDouble(),
                    title: '${item['percentage']}%',
                    radius: 45.0,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(item['category'] as String, style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('$symbol${(item['amount'] as num).toStringAsFixed(2)} (${item['percentage']}%)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSpendingPieChart(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No member spending data')));

    final colors = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      Colors.blueGrey,
      Colors.grey,
      Colors.black87,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: List.generate(items.length, (i) {
                  final item = items[i];
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: (item['amount'] as num).toDouble(),
                    title: '${item['percentage']}%',
                    radius: 45.0,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(item['userName'] as String, style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('$symbol${(item['amount'] as num).toStringAsFixed(2)} (${item['percentage']}%)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBalancesSection(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: items.map((m) {
        final net = (m['netBalance'] as num).toDouble();
        final isPositive = net > 0.01;
        final isNegative = net < -0.01;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m['userName'] as String, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    isPositive ? '+$symbol${net.toStringAsFixed(2)}' : isNegative ? '-$symbol${net.abs().toStringAsFixed(2)}' : 'Settled',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : isNegative ? Colors.red : cs.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paid: $symbol${(m['totalPaid'] as num).toStringAsFixed(2)}', style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary)),
                  Text('Share: $symbol${(m['totalShare'] as num).toStringAsFixed(2)}', style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyTrendChart(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    final spots = List.generate(items.length, (i) => FlSpot(i.toDouble(), (items[i]['amount'] as num).toDouble()));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < items.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(items[idx]['label'] as String, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: cs.primary,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: cs.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownList(ThemeData theme, ColorScheme cs, List<Map<String, dynamic>> items, String symbol) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.map((item) {
          return ListTile(
            dense: true,
            title: Text(item['category'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${item['count']} expense${(item['count'] as num) > 1 ? 's' : ''} • Avg: $symbol${(item['averageExpense'] as num).toStringAsFixed(2)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$symbol${(item['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${item['percentage']}%', style: TextStyle(fontSize: 11, color: cs.secondary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopStatisticsGrid(ThemeData theme, ColorScheme cs, Map<String, dynamic> stats, String symbol) {
    final highestExp = stats['highestExpense'] as Map<String, dynamic>? ?? {};
    final highestSpender = stats['highestSpender'] as Map<String, dynamic>? ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _topStatCard(theme, cs, 'Highest Expense', highestExp['title'] ?? 'None', '$symbol${(highestExp['amount'] ?? 0).toStringAsFixed(2)}'),
        _topStatCard(theme, cs, 'Highest Spender', highestSpender['userName'] ?? 'None', '$symbol${(highestSpender['amount'] ?? 0).toStringAsFixed(2)}'),
        _topStatCard(theme, cs, 'Largest Settlement', 'Completed', '$symbol${(stats['largestSettlement'] ?? 0).toStringAsFixed(2)}'),
        _topStatCard(theme, cs, 'Most Used Category', stats['mostUsedCategory'] ?? 'None', 'Top Frequency'),
        _topStatCard(theme, cs, 'Average Expense', 'Per Transaction', '$symbol${(stats['averageExpense'] ?? 0).toStringAsFixed(2)}'),
        _topStatCard(theme, cs, 'Per Member Avg', 'Total Distributed', '$symbol${(stats['averageExpensePerMember'] ?? 0).toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _topStatCard(ThemeData theme, ColorScheme cs, String title, String mainVal, String subVal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.labelSmall?.copyWith(color: cs.secondary)),
          const SizedBox(height: 2),
          Text(mainVal, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subVal, style: theme.textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
