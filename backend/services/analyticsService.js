import { sql } from '../db.js';

export async function getGroupAnalytics({ groupId, filter, startDate, endDate }) {
  const groups = await sql`SELECT * FROM groups WHERE id = ${groupId}`;
  if (groups.length === 0) return null;
  const group = groups[0];

  const members = await sql`
    SELECT gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
    FROM group_members gm
    JOIN users u ON gm.user_id = u.id
    WHERE gm.group_id = ${groupId}
  `;

  const userNameMap = {};
  members.forEach((m) => {
    userNameMap[m.user_id] = m.name || m.email || 'Member';
  });

  let rawExpenses = await sql`
    SELECT e.*, u.name AS paid_by_name
    FROM expenses e
    JOIN users u ON e.paid_by = u.id
    WHERE e.group_id = ${groupId}
    ORDER BY e.expense_date DESC, e.created_at DESC
  `;

  let settlements = await sql`
    SELECT s.*, fu.name AS from_user_name, tu.name AS to_user_name
    FROM settlements s
    JOIN users fu ON s.from_user = fu.id
    JOIN users tu ON s.to_user = tu.id
    WHERE s.group_id = ${groupId}
    ORDER BY s.created_at DESC
  `;

  // ── Date Filtering ────────────────────────────────────────────────
  const now = new Date();
  let filterStart = null;
  let filterEnd = null;

  if (filter === 'this_week') {
    const day = now.getDay();
    const diff = now.getDate() - day + (day === 0 ? -6 : 1); // Monday start
    filterStart = new Date(now.setDate(diff));
    filterStart.setHours(0, 0, 0, 0);
  } else if (filter === 'this_month') {
    filterStart = new Date(now.getFullYear(), now.getMonth(), 1);
  } else if (filter === 'last_month') {
    filterStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    filterEnd = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
  } else if (filter === 'custom' && startDate && endDate) {
    filterStart = new Date(startDate);
    filterEnd = new Date(endDate);
  }

  if (filterStart) {
    rawExpenses = rawExpenses.filter((e) => {
      const d = new Date(e.expense_date || e.created_at);
      if (filterEnd) return d >= filterStart && d <= filterEnd;
      return d >= filterStart;
    });
  }

  const expenseIds = rawExpenses.map((e) => e.id);
  const participants = expenseIds.length > 0 ? await sql`
    SELECT ep.*, u.name AS user_name
    FROM expense_participants ep
    JOIN users u ON ep.user_id = u.id
    WHERE ep.expense_id = ANY(${expenseIds})
  ` : [];

  const expenses = rawExpenses.map((e) => ({
    ...e,
    participants: participants.filter((p) => p.expense_id === e.id),
  }));

  // ── Calculations ──────────────────────────────────────────────────
  const totalExpensesAmt = expenses.reduce((sum, e) => sum + parseFloat(e.amount || 0), 0);
  const totalMembersCount = members.length;
  const completedSettlements = settlements.filter((s) => (s.status || '').toLowerCase() === 'completed');
  const totalSettlementsAmt = completedSettlements.reduce((sum, s) => sum + parseFloat(s.amount || 0), 0);

  // Lifetime in days
  const createdDate = new Date(group.created_at);
  const diffTime = Math.abs(new Date() - createdDate);
  const groupLifetimeDays = Math.max(1, Math.ceil(diffTime / (1000 * 60 * 60 * 24)));

  // Member balances
  const memberStats = members.map((m) => {
    const mId = m.user_id;
    let paid = 0;
    let share = 0;

    expenses.forEach((e) => {
      if (e.paid_by === mId) paid += parseFloat(e.amount || 0);
      (e.participants || []).forEach((p) => {
        if (p.user_id === mId) share += parseFloat(p.share_amount || 0);
      });
    });

    let sentSettlements = 0;
    let receivedSettlements = 0;
    completedSettlements.forEach((s) => {
      if (s.from_user === mId) sentSettlements += parseFloat(s.amount || 0);
      if (s.to_user === mId) receivedSettlements += parseFloat(s.amount || 0);
    });

    const netBalance = (paid - share) + sentSettlements - receivedSettlements;

    return {
      userId: mId,
      userName: m.name || m.email || 'Member',
      avatarId: m.avatar_id || 'avatar_1',
      totalPaid: Math.round(paid * 100) / 100,
      totalShare: Math.round(share * 100) / 100,
      netBalance: Math.round(netBalance * 100) / 100,
    };
  });

  const positiveBalances = memberStats.filter((m) => m.netBalance > 0.01);
  const outstandingBalanceAmt = positiveBalances.reduce((sum, m) => sum + m.netBalance, 0);

  // 1. Expense Distribution (Pie Chart by Category)
  const categoryMap = {};
  expenses.forEach((e) => {
    const cat = e.category || 'Other';
    categoryMap[cat] = (categoryMap[cat] || 0) + parseFloat(e.amount || 0);
  });
  const categoryDistribution = Object.entries(categoryMap).map(([category, amount]) => ({
    category,
    amount: Math.round(amount * 100) / 100,
    percentage: totalExpensesAmt > 0 ? Math.round((amount / totalExpensesAmt) * 10000) / 100 : 0,
  })).sort((a, b) => b.amount - a.amount);

  // 2. Member Spending (Pie Chart by Member Share)
  const memberSpendingMap = {};
  expenses.forEach((e) => {
    (e.participants || []).forEach((p) => {
      const uName = userNameMap[p.user_id] || p.user_name || 'Member';
      memberSpendingMap[uName] = (memberSpendingMap[uName] || 0) + parseFloat(p.share_amount || 0);
    });
  });
  const memberSpending = Object.entries(memberSpendingMap).map(([userName, amount]) => ({
    userName,
    amount: Math.round(amount * 100) / 100,
    percentage: totalExpensesAmt > 0 ? Math.round((amount / totalExpensesAmt) * 10000) / 100 : 0,
  })).sort((a, b) => b.amount - a.amount);

  // 3. Monthly Spending Trend (Line Chart)
  const monthMap = {};
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  expenses.forEach((e) => {
    const d = new Date(e.expense_date || e.created_at);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = `${monthNames[d.getMonth()]} ${d.getFullYear()}`;
    if (!monthMap[key]) monthMap[key] = { label, amount: 0, sortKey: key };
    monthMap[key].amount += parseFloat(e.amount || 0);
  });
  const monthlyTrend = Object.values(monthMap)
    .sort((a, b) => a.sortKey.localeCompare(b.sortKey))
    .map((item) => ({
      label: item.label,
      amount: Math.round(item.amount * 100) / 100,
    }));

  // 4. Category Breakdown Table
  const categoryCounts = {};
  expenses.forEach((e) => {
    const cat = e.category || 'Other';
    categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
  });
  const categoryBreakdown = categoryDistribution.map((item) => {
    const count = categoryCounts[item.category] || 0;
    return {
      ...item,
      count,
      averageExpense: count > 0 ? Math.round((item.amount / count) * 100) / 100 : 0,
    };
  });

  // 5. Top Statistics Cards
  let highestExpense = { title: 'None', amount: 0 };
  if (expenses.length > 0) {
    const topExp = [...expenses].sort((a, b) => parseFloat(b.amount) - parseFloat(a.amount))[0];
    highestExpense = { title: topExp.title, amount: parseFloat(topExp.amount) };
  }

  const highestSpenderObj = memberSpending[0] || { userName: 'None', amount: 0 };
  const mostUsedCatObj = [...categoryBreakdown].sort((a, b) => b.count - a.count)[0] || { category: 'None', count: 0 };

  const totalTxns = expenses.length + completedSettlements.length;
  const avgExp = expenses.length > 0 ? totalExpensesAmt / expenses.length : 0;
  const avgPerMember = totalMembersCount > 0 ? totalExpensesAmt / totalMembersCount : 0;
  const avgPerTxn = totalTxns > 0 ? totalExpensesAmt / totalTxns : 0;

  const topStatistics = {
    highestExpense,
    highestSpender: { userName: highestSpenderObj.userName, amount: highestSpenderObj.amount },
    mostActiveMember: { userName: highestSpenderObj.userName },
    largestSettlement: completedSettlements.length > 0
      ? Math.max(...completedSettlements.map((s) => parseFloat(s.amount)))
      : 0,
    mostUsedCategory: mostUsedCatObj.category,
    averageExpense: Math.round(avgExp * 100) / 100,
    averageExpensePerMember: Math.round(avgPerMember * 100) / 100,
    averageExpensePerTransaction: Math.round(avgPerTxn * 100) / 100,
  };

  // 6. Settlement Progress
  const totalSettledAmt = totalSettlementsAmt;
  const remainingAmt = outstandingBalanceAmt;
  const totalTarget = totalSettledAmt + remainingAmt;
  const progressPercentage = totalTarget > 0 ? Math.round((totalSettledAmt / totalTarget) * 100) : 100;

  return {
    group: {
      id: group.id,
      name: group.name,
      isLocked: Boolean(group.is_locked),
    },
    overview: {
      totalExpenses: Math.round(totalExpensesAmt * 100) / 100,
      totalMembers: totalMembersCount,
      totalSettlements: completedSettlements.length,
      outstandingBalance: Math.round(outstandingBalanceAmt * 100) / 100,
      totalTransactions: totalTxns,
      groupLifetimeDays,
    },
    categoryDistribution,
    memberSpending,
    memberBalances: memberStats,
    monthlyTrend,
    categoryBreakdown,
    topStatistics,
    settlementProgress: {
      totalOutstanding: Math.round(outstandingBalanceAmt * 100) / 100,
      totalSettled: Math.round(totalSettledAmt * 100) / 100,
      remaining: Math.round(remainingAmt * 100) / 100,
      progressPercentage,
      isFullySettled: remainingAmt <= 0.01,
    },
  };
}
