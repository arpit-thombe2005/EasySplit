import PDFDocument from 'pdfkit';

function computeSimplifiedDebts(members, expenses, settlements) {
  const userNameMap = {};
  const netBalances = {};
  const clean = (id) => (id || '').toLowerCase().trim();

  function registerUser(rawId, name) {
    const id = clean(rawId);
    if (!id) return;
    if (netBalances[id] === undefined) netBalances[id] = 0.0;
    if (name && name !== 'Unknown' && name !== 'Member') userNameMap[id] = name;
  }

  for (const m of members) registerUser(m.user_id || m.userId, m.name || m.user?.name);

  for (const e of expenses) {
    const payerId = clean(e.paid_by || e.paidBy);
    registerUser(e.paid_by || e.paidBy, e.paid_by_name || e.paidByUser?.name);
    if (payerId) netBalances[payerId] = (netBalances[payerId] || 0) + parseFloat(e.amount);

    for (const p of (e.participants || [])) {
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

export async function generateGroupPdfReport({ group, members, expenses, settlements }) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40, size: 'A4', bufferPages: true });
      const buffers = [];

      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err) => reject(err));

      const primaryColor = '#1E1E1E';
      const secondaryColor = '#555555';
      const accentColor = '#2563EB';
      const lightBg = '#F8FAFC';

      // ── Cover / Header ──────────────────────────────────────────────
      doc.rect(0, 0, doc.page.width, 100).fill(primaryColor);
      doc.fillColor('#FFFFFF').fontSize(26).font('Helvetica-Bold').text('EasySplit Report', 40, 30);
      doc.fontSize(14).font('Helvetica').text(`Group: ${group.name}`, 40, 65);

      let y = 120;

      // ── Group Information ───────────────────────────────────────────
      doc.fillColor(primaryColor).fontSize(16).font('Helvetica-Bold').text('1. Group Information', 40, y);
      y += 25;

      const totalExpAmt = expenses.reduce((sum, e) => sum + parseFloat(e.amount || 0), 0);
      const owner = members.find((m) => (m.user_id || m.userId) === group.created_by) || members[0];
      const ownerName = owner?.name || owner?.user?.name || 'Owner';

      const infoRows = [
        ['Group Name:', group.name, 'Created By:', ownerName],
        ['Export Date:', new Date().toISOString().split('T')[0], 'Total Members:', `${members.length}`],
        ['Total Expenses:', `₹${totalExpAmt.toFixed(2)}`, 'Total Settlements:', `${settlements.length}`],
      ];

      doc.fontSize(10).font('Helvetica');
      infoRows.forEach((row) => {
        doc.fillColor(secondaryColor).text(row[0], 40, y, { width: 100 });
        doc.fillColor(primaryColor).font('Helvetica-Bold').text(row[1], 140, y, { width: 140 });
        doc.font('Helvetica').fillColor(secondaryColor).text(row[2], 290, y, { width: 100 });
        doc.fillColor(primaryColor).font('Helvetica-Bold').text(row[3], 390, y, { width: 140 });
        y += 18;
      });

      y += 15;

      // ── Members Roster ──────────────────────────────────────────────
      doc.fillColor(primaryColor).fontSize(14).font('Helvetica-Bold').text('2. Member Roster', 40, y);
      y += 20;

      doc.rect(40, y, doc.page.width - 80, 20).fill('#E2E8F0');
      doc.fillColor(primaryColor).fontSize(10).font('Helvetica-Bold');
      doc.text('Name', 48, y + 5);
      doc.text('Email', 220, y + 5);
      doc.text('Role', 450, y + 5);
      y += 22;

      doc.font('Helvetica');
      members.forEach((m) => {
        const isOwner = (m.user_id || m.userId) === group.created_by;
        doc.fillColor(primaryColor).text(m.name || m.user?.name || 'Member', 48, y);
        doc.fillColor(secondaryColor).text(m.email || m.user?.email || 'N/A', 220, y);
        doc.fillColor(isOwner ? accentColor : primaryColor).text(isOwner ? 'Owner' : 'Member', 450, y);
        y += 18;
      });

      y += 20;

      // ── Expense Ledger ──────────────────────────────────────────────
      if (y > 650) { doc.addPage(); y = 40; }
      doc.fillColor(primaryColor).fontSize(14).font('Helvetica-Bold').text('3. Expense History', 40, y);
      y += 20;

      doc.rect(40, y, doc.page.width - 80, 20).fill('#E2E8F0');
      doc.fillColor(primaryColor).fontSize(9).font('Helvetica-Bold');
      doc.text('Title', 48, y + 5, { width: 140 });
      doc.text('Category', 190, y + 5, { width: 90 });
      doc.text('Paid By', 280, y + 5, { width: 110 });
      doc.text('Amount (₹)', 400, y + 5, { width: 70, align: 'right' });
      doc.text('Date', 480, y + 5, { width: 70, align: 'right' });
      y += 22;

      doc.font('Helvetica').fontSize(9);
      expenses.forEach((e) => {
        if (y > 750) { doc.addPage(); y = 40; }
        doc.fillColor(primaryColor).text(e.title, 48, y, { width: 135 });
        doc.fillColor(secondaryColor).text(e.category || 'Other', 190, y, { width: 85 });
        doc.fillColor(primaryColor).text(e.paid_by_name || e.paidByUser?.name || 'Member', 280, y, { width: 110 });
        doc.font('Helvetica-Bold').text(parseFloat(e.amount).toFixed(2), 400, y, { width: 70, align: 'right' });
        doc.font('Helvetica').fillColor(secondaryColor).text(e.expense_date ? new Date(e.expense_date).toISOString().split('T')[0] : 'N/A', 480, y, { width: 70, align: 'right' });
        y += 18;
      });

      y += 20;

      // ── Current Balances & Debt Simplification ──────────────────────
      if (y > 600) { doc.addPage(); y = 40; }
      doc.fillColor(primaryColor).fontSize(14).font('Helvetica-Bold').text('4. Debt Simplification Summary', 40, y);
      y += 20;

      const simplified = computeSimplifiedDebts(members, expenses, settlements);
      if (simplified.length === 0) {
        doc.fillColor(secondaryColor).fontSize(10).font('Helvetica-Oblique').text('🎉 All balances are completely settled!', 48, y);
        y += 20;
      } else {
        doc.rect(40, y, doc.page.width - 80, 20).fill('#E2E8F0');
        doc.fillColor(primaryColor).fontSize(9).font('Helvetica-Bold');
        doc.text('Payer (Who Pays)', 48, y + 5);
        doc.text('Receiver (Who Receives)', 240, y + 5);
        doc.text('Amount (₹)', 440, y + 5, { align: 'right' });
        y += 22;

        doc.font('Helvetica').fontSize(9);
        simplified.forEach((s) => {
          if (y > 750) { doc.addPage(); y = 40; }
          doc.fillColor(primaryColor).text(s.fromUserName, 48, y);
          doc.text(s.toUserName, 240, y);
          doc.font('Helvetica-Bold').fillColor('#16A34A').text(`₹${s.amount.toFixed(2)}`, 440, y, { align: 'right' });
          doc.font('Helvetica');
          y += 18;
        });
      }

      // ── Footer & Page Numbers ──────────────────────────────────────
      const range = doc.bufferedPageRange();
      for (let i = range.start; i < range.start + range.count; i++) {
        doc.switchToPage(i);
        doc.rect(40, doc.page.height - 35, doc.page.width - 80, 0.5).fill('#CBD5E1');
        doc.fillColor(secondaryColor).fontSize(8).font('Helvetica');
        doc.text('EasySplit Expense Settlement Report', 40, doc.page.height - 25);
        doc.text(`Page ${i + 1} of ${range.count}`, doc.page.width - 120, doc.page.height - 25, { align: 'right' });
      }

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}
