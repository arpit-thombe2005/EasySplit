import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { emitToGroup } from '../index.js';

const router = express.Router();

// ── Expense Enricher ──────────────────────────────────────────────
async function enrichExpenses(expenses) {
  if (expenses.length === 0) return [];

  const expenseIds = expenses.map(e => e.id);
  const userIds = [...new Set(expenses.map(e => e.paid_by))];

  const [participants, payers] = await Promise.all([
    sql`
      SELECT ep.*, u.name, u.email, u.avatar_id
      FROM expense_participants ep
      JOIN users u ON ep.user_id = u.id
      WHERE ep.expense_id = ANY(${expenseIds})
    `,
    sql`
      SELECT id, name, email, avatar_id FROM users WHERE id = ANY(${userIds})
    `,
  ]);

  const payerMap = new Map(payers.map(p => [p.id, p]));
  const partMap = new Map();
  participants.forEach(p => {
    if (!partMap.has(p.expense_id)) partMap.set(p.expense_id, []);
    partMap.get(p.expense_id).push(p);
  });

  return expenses.map(e => {
    const payer = payerMap.get(e.paid_by) || {};
    const parts = partMap.get(e.id) || [];
    return {
      id: e.id,
      groupId: e.group_id,
      title: e.title,
      amount: parseFloat(e.amount),
      category: e.category,
      notes: e.notes,
      splitType: e.split_type,
      expenseDate: e.expense_date,
      createdAt: e.created_at,
      paidBy: {
        id: e.paid_by,
        name: payer.name || 'Unknown',
        email: payer.email,
        avatarId: payer.avatar_id || 'avatar_1',
      },
      participants: parts.map(p => ({
        id: p.id,
        expenseId: p.expense_id,
        userId: p.user_id,
        userName: p.name || 'Unknown',
        userEmail: p.email,
        userAvatarId: p.avatar_id || 'avatar_1',
        shareAmount: parseFloat(p.share_amount),
        percentage: p.percentage ? parseFloat(p.percentage) : null,
        shares: p.shares,
      })),
    };
  });
}

// ── GET /api/groups/:groupId/expenses ─────────────────────────────
async function getGroupExpensesHandler(req, res) {
  try {
    const { groupId } = req.params;
    const page = parseInt(req.query.page || '1');
    const limit = parseInt(req.query.limit || '50');
    const offset = (page - 1) * limit;

    const expenses = await sql`
      SELECT * FROM expenses
      WHERE group_id = ${groupId}
      ORDER BY expense_date DESC, created_at DESC
      LIMIT ${limit} OFFSET ${offset}
    `;

    const totalRows = await sql`
      SELECT COUNT(*) FROM expenses WHERE group_id = ${groupId}
    `;

    const enriched = await enrichExpenses(expenses);
    return res.json({
      expenses: enriched,
      total: parseInt(totalRows[0].count),
      page,
      limit,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch group expenses' });
  }
}

router.get('/groups/:groupId/expenses', authMiddleware, getGroupExpensesHandler);
router.get('/:groupId/expenses', authMiddleware, getGroupExpensesHandler);

// ── GET /api/expenses/me ──────────────────────────────────────────
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1');
    const limit = parseInt(req.query.limit || '50');
    const offset = (page - 1) * limit;

    const expenses = await sql`
      SELECT DISTINCT e.*
      FROM expenses e
      LEFT JOIN expense_participants ep ON e.id = ep.expense_id
      WHERE e.paid_by = ${req.user.userId} OR ep.user_id = ${req.user.userId}
      ORDER BY e.expense_date DESC, e.created_at DESC
      LIMIT ${limit} OFFSET ${offset}
    `;

    const enriched = await enrichExpenses(expenses);
    return res.json({ expenses: enriched });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch user expenses' });
  }
});

// ── GET /api/expenses/:expenseId ──────────────────────────────────
router.get('/:expenseId', authMiddleware, async (req, res) => {
  try {
    const expenses = await sql`
      SELECT * FROM expenses WHERE id = ${req.params.expenseId}
    `;
    if (expenses.length === 0) return res.status(404).json({ error: 'Expense not found' });

    const enriched = await enrichExpenses(expenses);
    return res.json({ expense: enriched[0] });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch expense' });
  }
});

// ── POST /api/expenses ────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    const {
      group_id, groupId, paid_by, paidBy, title, amount, category, notes,
      split_type, splitType, expense_date, expenseDate, participants,
    } = req.body;

    const targetGroupId = group_id || groupId;
    const targetPaidBy = paid_by || paidBy || req.user.userId;
    const targetSplitType = split_type || splitType || 'equal';
    const targetExpenseDate = expense_date || expenseDate;

    if (!title?.trim()) return res.status(400).json({ error: 'Title is required' });
    if (!amount || parseFloat(amount) <= 0) return res.status(400).json({ error: 'Valid amount is required' });
    if (!participants || participants.length === 0) {
      return res.status(400).json({ error: 'At least one participant is required' });
    }

    const expenseId = uuidv4();

    await sql`
      INSERT INTO expenses (id, group_id, paid_by, title, amount, category, notes, split_type, expense_date)
      VALUES (
        ${expenseId},
        ${targetGroupId},
        ${targetPaidBy},
        ${title.trim()},
        ${parseFloat(amount)},
        ${category || 'Other'},
        ${notes || null},
        ${targetSplitType},
        ${targetExpenseDate ? new Date(targetExpenseDate) : new Date()}
      )
    `;

    const parsedParticipants = typeof participants === 'string'
      ? JSON.parse(participants)
      : participants;

    for (const p of parsedParticipants) {
      const pUserId = p.user_id || p.userId;
      const pShareAmount = p.share_amount !== undefined ? p.share_amount : p.shareAmount;
      await sql`
        INSERT INTO expense_participants (id, expense_id, user_id, share_amount, percentage, shares)
        VALUES (${uuidv4()}, ${expenseId}, ${pUserId}, ${parseFloat(pShareAmount || 0)}, ${parseFloat(p.percentage || 0)}, ${p.shares || 1})
      `;
    }

    await sql`UPDATE groups SET updated_at = NOW() WHERE id = ${targetGroupId}`;

    const expenses = await sql`SELECT * FROM expenses WHERE id = ${expenseId}`;
    const enriched = await enrichExpenses(expenses);

    // Broadcast real-time socket event to all active members of this group!
    emitToGroup(targetGroupId, 'realtime_update', { type: 'expense_created', groupId: targetGroupId, expense: enriched[0] });

    return res.status(201).json({ expense: enriched[0] });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to create expense' });
  }
});

// ── PUT /api/expenses/:expenseId ──────────────────────────────────
router.put('/:expenseId', authMiddleware, async (req, res) => {
  try {
    const { expenseId } = req.params;
    const { title, amount, category, notes, split_type, splitType, expense_date, expenseDate, participants } = req.body;
    const targetSplitType = split_type || splitType;
    const targetExpenseDate = expense_date || expenseDate;

    await sql`
      UPDATE expenses SET
        title = COALESCE(${title ?? null}, title),
        amount = COALESCE(${amount ? parseFloat(amount) : null}, amount),
        category = COALESCE(${category ?? null}, category),
        notes = COALESCE(${notes ?? null}, notes),
        split_type = COALESCE(${targetSplitType ?? null}, split_type),
        expense_date = COALESCE(${targetExpenseDate ? new Date(targetExpenseDate) : null}, expense_date)
      WHERE id = ${expenseId}
    `;

    if (participants) {
      await sql`DELETE FROM expense_participants WHERE expense_id = ${expenseId}`;
      for (const p of participants) {
        const pUserId = p.user_id || p.userId;
        const pShareAmount = p.share_amount !== undefined ? p.share_amount : p.shareAmount;
        await sql`
          INSERT INTO expense_participants (id, expense_id, user_id, share_amount, percentage, shares)
          VALUES (${uuidv4()}, ${expenseId}, ${pUserId}, ${parseFloat(pShareAmount || 0)}, ${parseFloat(p.percentage || 0)}, ${p.shares || 1})
        `;
      }
    }

    const expenses = await sql`SELECT * FROM expenses WHERE id = ${expenseId}`;
    const enriched = await enrichExpenses(expenses);
    if (enriched[0]?.groupId) {
      emitToGroup(enriched[0].groupId, 'realtime_update', { type: 'expense_updated', groupId: enriched[0].groupId, expense: enriched[0] });
    }

    return res.json({ expense: enriched[0] });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update expense' });
  }
});

// ── DELETE /api/expenses/:expenseId ──────────────────────────────
router.delete('/:expenseId', authMiddleware, async (req, res) => {
  try {
    const existing = await sql`SELECT group_id FROM expenses WHERE id = ${req.params.expenseId}`;
    await sql`DELETE FROM expenses WHERE id = ${req.params.expenseId} AND paid_by = ${req.user.userId}`;
    if (existing[0]?.group_id) {
      emitToGroup(existing[0].group_id, 'realtime_update', { type: 'expense_deleted', groupId: existing[0].group_id, expenseId: req.params.expenseId });
    }
    return res.json({ message: 'Expense deleted' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to delete expense' });
  }
});

export default router;
