import ExcelJS from 'exceljs';

function computeSimplifiedDebts(members, expenses, settlements) {
  const userNameMap = {};
  const netBalances = {};

  const clean = (id) => (id || '').toLowerCase().trim();

  function registerUser(rawId, name) {
    const id = clean(rawId);
    if (!id) return;
    if (netBalances[id] === undefined) netBalances[id] = 0.0;
    if (name && name !== 'Unknown' && name !== 'Member') {
      userNameMap[id] = name;
    }
  }

  for (const m of members) {
    registerUser(m.user_id || m.userId, m.name || m.user?.name);
  }

  for (const e of expenses) {
    const payerId = clean(e.paid_by || e.paidBy);
    registerUser(e.paid_by || e.paidBy, e.paid_by_name || e.paidByUser?.name);
    if (payerId) netBalances[payerId] = (netBalances[payerId] || 0) + parseFloat(e.amount);

    const participants = e.participants || [];
    for (const p of participants) {
      const partId = clean(p.user_id || p.userId);
      registerUser(p.user_id || p.userId, p.user_name || p.user?.name);
      if (partId) netBalances[partId] = (netBalances[partId] || 0) - parseFloat(p.share_amount || p.shareAmount);
    }
  }

  for (const s of settlements) {
    const fromId = clean(s.from_user || s.fromUser);
    const toId = clean(s.to_user || s.toUser);
    registerUser(s.from_user || s.fromUser, s.from_user_name || s.fromUserName);
    registerUser(s.to_user || s.toUser, s.to_user_name || s.toUserName);
    if ((s.status || '').toLowerCase() === 'completed') {
      if (fromId) netBalances[fromId] = (netBalances[fromId] || 0) + parseFloat(s.amount);
      if (toId) netBalances[toId] = (netBalances[toId] || 0) - parseFloat(s.amount);
    }
  }

  const creditors = [];
  const debtors = [];

  Object.entries(netBalances).forEach(([userId, balance]) => {
    const rounded = Math.round(balance * 100) / 100;
    if (rounded > 0.01) creditors.push({ userId, amount: rounded });
    else if (rounded < -0.01) debtors.push({ userId, amount: Math.abs(rounded) });
  });

  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  const result = [];
  let i = 0, j = 0;

  while (i < creditors.length && j < debtors.length) {
    const creditor = creditors[i];
    const debtor = debtors[j];

    const settledAmount = Math.min(creditor.amount, debtor.amount);
    const roundedSettled = Math.round(settledAmount * 100) / 100;

    if (roundedSettled > 0.01) {
      result.push({
        fromUserName: userNameMap[debtor.userId] || 'Member',
        toUserName: userNameMap[creditor.userId] || 'Member',
        amount: roundedSettled,
      });
    }

    creditor.amount -= settledAmount;
    debtor.amount -= settledAmount;

    if (creditor.amount <= 0.01) i++;
    if (debtor.amount <= 0.01) j++;
  }

  return result;
}

export async function generateGroupExcelReport({ group, members, expenses, settlements }) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'EasySplit App';
  workbook.created = new Date();

  const headerFill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FF1E1E1E' },
  };
  const headerFont = { name: 'Calibri', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };

  function applyHeaderStyle(sheet) {
    sheet.getRow(1).height = 24;
    sheet.getRow(1).eachCell((cell) => {
      cell.fill = headerFill;
      cell.font = headerFont;
      cell.alignment = { vertical: 'middle', horizontal: 'left' };
    });
  }

  function autoFitColumns(sheet) {
    sheet.columns.forEach((col) => {
      let maxLen = col.header ? col.header.length : 10;
      col.eachCell({ includeEmpty: false }, (cell) => {
        const len = cell.value ? cell.value.toString().length : 0;
        if (len > maxLen) maxLen = len;
      });
      col.width = Math.min(Math.max(maxLen + 4, 12), 40);
    });
  }

  // ── Sheet 1: Group Information ────────────────────────────────────
  const s1 = workbook.addWorksheet('Group Information');
  s1.columns = [
    { header: 'Property', key: 'prop' },
    { header: 'Value', key: 'val' },
  ];
  const owner = members.find((m) => (m.user_id || m.userId) === group.created_by) || members[0];
  const ownerName = owner?.name || owner?.user?.name || 'Owner';
  const totalExpAmt = expenses.reduce((sum, e) => sum + parseFloat(e.amount || 0), 0);

  s1.addRows([
    { prop: 'Group Name', val: group.name },
    { prop: 'Owner', val: ownerName },
    { prop: 'Creation Date', val: group.created_at ? new Date(group.created_at).toISOString().split('T')[0] : 'N/A' },
    { prop: 'Export Date', val: new Date().toISOString().split('T')[0] },
    { prop: 'Total Members', val: members.length },
    { prop: 'Total Expenses', val: `₹${totalExpAmt.toFixed(2)}` },
    { prop: 'Total Settlements', val: settlements.length },
    { prop: 'Current Status', val: group.my_balance === 0 ? 'Settled' : 'Active Balances Pending' },
  ]);
  applyHeaderStyle(s1);
  autoFitColumns(s1);

  // ── Sheet 2: Members ──────────────────────────────────────────────
  const s2 = workbook.addWorksheet('Members');
  s2.columns = [
    { header: 'Name', key: 'name' },
    { header: 'Email', key: 'email' },
    { header: 'Role', key: 'role' },
    { header: 'Join Date', key: 'joinDate' },
  ];
  members.forEach((m) => {
    const isOwner = (m.user_id || m.userId) === group.created_by;
    s2.addRow({
      name: m.name || m.user?.name || 'Member',
      email: m.email || m.user?.email || 'N/A',
      role: isOwner ? 'Owner' : 'Member',
      joinDate: m.joined_at ? new Date(m.joined_at).toISOString().split('T')[0] : 'N/A',
    });
  });
  applyHeaderStyle(s2);
  autoFitColumns(s2);

  // ── Sheet 3: Expenses ─────────────────────────────────────────────
  const s3 = workbook.addWorksheet('Expenses');
  s3.columns = [
    { header: 'Expense Title', key: 'title' },
    { header: 'Category', key: 'category' },
    { header: 'Paid By', key: 'paidBy' },
    { header: 'Total Amount (₹)', key: 'amount' },
    { header: 'Split Type', key: 'splitType' },
    { header: 'Participants', key: 'participants' },
    { header: 'Expense Date', key: 'expenseDate' },
    { header: 'Notes', key: 'notes' },
    { header: 'Created At', key: 'createdAt' },
  ];
  expenses.forEach((e) => {
    const partNames = (e.participants || []).map((p) => p.user_name || p.user?.name || 'Member').join(', ');
    s3.addRow({
      title: e.title,
      category: e.category || 'Other',
      paidBy: e.paid_by_name || e.paidByUser?.name || e.paid_by,
      amount: parseFloat(e.amount).toFixed(2),
      splitType: e.split_type || e.splitType || 'equal',
      participants: partNames,
      expenseDate: e.expense_date ? new Date(e.expense_date).toISOString().split('T')[0] : 'N/A',
      notes: e.notes || '-',
      createdAt: e.created_at ? new Date(e.created_at).toISOString().split('T')[0] : 'N/A',
    });
  });
  applyHeaderStyle(s3);
  autoFitColumns(s3);

  // ── Sheet 4: Expense Participants ─────────────────────────────────
  const s4 = workbook.addWorksheet('Expense Participants');
  s4.columns = [
    { header: 'Expense', key: 'expense' },
    { header: 'Participant', key: 'participant' },
    { header: 'Share Amount (₹)', key: 'shareAmount' },
    { header: 'Percentage (%)', key: 'percentage' },
    { header: 'Shares', key: 'shares' },
  ];
  expenses.forEach((e) => {
    (e.participants || []).forEach((p) => {
      s4.addRow({
        expense: e.title,
        participant: p.user_name || p.user?.name || p.user_id,
        shareAmount: parseFloat(p.share_amount || p.shareAmount || 0).toFixed(2),
        percentage: p.percentage ? `${p.percentage}%` : '-',
        shares: p.shares || '-',
      });
    });
  });
  applyHeaderStyle(s4);
  autoFitColumns(s4);

  // ── Sheet 5: Settlement History ───────────────────────────────────
  const s5 = workbook.addWorksheet('Settlement History');
  s5.columns = [
    { header: 'Payer', key: 'payer' },
    { header: 'Receiver', key: 'receiver' },
    { header: 'Amount (₹)', key: 'amount' },
    { header: 'Payment Method', key: 'method' },
    { header: 'Status', key: 'status' },
    { header: 'Payment Date', key: 'date' },
    { header: 'Note', key: 'note' },
  ];
  settlements.forEach((s) => {
    s5.addRow({
      payer: s.from_user_name || s.fromUserName || s.from_user,
      receiver: s.to_user_name || s.toUserName || s.to_user,
      amount: parseFloat(s.amount).toFixed(2),
      method: s.payment_method || s.paymentMethod || 'UPI',
      status: (s.status || 'pending').toUpperCase(),
      date: s.created_at ? new Date(s.created_at).toISOString().split('T')[0] : 'N/A',
      note: s.note || '-',
    });
  });
  applyHeaderStyle(s5);
  autoFitColumns(s5);

  // ── Sheet 6: Current Balances ──────────────────────────────────────
  const s6 = workbook.addWorksheet('Current Balances');
  s6.columns = [
    { header: 'Member', key: 'member' },
    { header: 'Total Paid (₹)', key: 'totalPaid' },
    { header: 'Total Share (₹)', key: 'totalShare' },
    { header: 'Net Balance (₹)', key: 'netBalance' },
  ];
  members.forEach((m) => {
    const mId = (m.user_id || m.userId || '').toLowerCase().trim();
    let paid = 0;
    let share = 0;

    expenses.forEach((e) => {
      if ((e.paid_by || e.paidBy || '').toLowerCase().trim() === mId) {
        paid += parseFloat(e.amount || 0);
      }
      (e.participants || []).forEach((p) => {
        if ((p.user_id || p.userId || '').toLowerCase().trim() === mId) {
          share += parseFloat(p.share_amount || p.shareAmount || 0);
        }
      });
    });

    let sentSettlements = 0;
    let receivedSettlements = 0;
    settlements.forEach((s) => {
      if ((s.status || '').toLowerCase() === 'completed') {
        if ((s.from_user || s.fromUser || '').toLowerCase().trim() === mId) sentSettlements += parseFloat(s.amount || 0);
        if ((s.to_user || s.toUser || '').toLowerCase().trim() === mId) receivedSettlements += parseFloat(s.amount || 0);
      }
    });

    const net = (paid - share) + sentSettlements - receivedSettlements;

    s6.addRow({
      member: m.name || m.user?.name || 'Member',
      totalPaid: paid.toFixed(2),
      totalShare: share.toFixed(2),
      netBalance: net.toFixed(2),
    });
  });
  applyHeaderStyle(s6);
  autoFitColumns(s6);

  // ── Sheet 7: Simplified Settlement Summary ────────────────────────
  const s7 = workbook.addWorksheet('Simplified Summary');
  s7.columns = [
    { header: 'Who Pays', key: 'from' },
    { header: 'Who Receives', key: 'to' },
    { header: 'Amount (₹)', key: 'amount' },
  ];
  const simplified = computeSimplifiedDebts(members, expenses, settlements);
  simplified.forEach((d) => {
    s7.addRow({
      from: d.fromUserName,
      to: d.toUserName,
      amount: d.amount.toFixed(2),
    });
  });
  applyHeaderStyle(s7);
  autoFitColumns(s7);

  const buffer = await workbook.xlsx.writeBuffer();
  return buffer;
}
