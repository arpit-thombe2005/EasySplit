import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';

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

  const payerMap = Object.fromEntries(payers.map(u => [u.id, u]));

  return expenses.map(e => ({
    id: e.id,
    groupId: e.group_id,
    group_id: e.group_id,
    paidBy: e.paid_by,
    paid_by: e.paid_by,
    title: e.title,
    amount: parseFloat(e.amount),
    category: e.category,
    notes: e.notes,
    splitType: e.split_type,
    split_type: e.split_type,
    expenseDate: e.expense_date,
    expense_date: e.expense_date,
    createdAt: e.created_at,
    created_at: e.created_at,
    paidByUser: payerMap[e.paid_by]
      ? {
          id: payerMap[e.paid_by].id,
          name: payerMap[e.paid_by].name,
          email: payerMap[e.paid_by].email,
          avatarId: payerMap[e.paid_by].avatar_id,
          avatar_id: payerMap[e.paid_by].avatar_id,
        }
      : null,
    participants: participants
      .filter(p => p.expense_id === e.id)
      .map(p => ({
        id: p.id,
        expenseId: p.expense_id,
        expense_id: p.expense_id,
        userId: p.user_id,
        user_id: p.user_id,
        shareAmount: parseFloat(p.share_amount),
        share_amount: parseFloat(p.share_amount),
        percentage: parseFloat(p.percentage || 0),
        shares: p.shares || 1,
        user: { id: p.user_id, name: p.name, email: p.email, avatarId: p.avatar_id, avatar_id: p.avatar_id },
      })),
  }));
}

// ── GET /api/groups/:groupId/expenses ─────────────────────────────
export async function getGroupExpensesHandler(req, res) {
  try {
    const { groupId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const expenses = await sql`
      SELECT * FROM expenses
      WHERE group_id = ${groupId}
      ORDER BY expense_date DESC, created_at DESC
      LIMIT ${limit} OFFSET ${offset}
    `;

    const enriched = await enrichExpenses(expenses);
    return res.json({ expenses: enriched, page, limit });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch expenses' });
  }
}

router.get('/groups/:groupId/expenses', authMiddleware, getGroupExpensesHandler);
router.get('/:groupId/expenses', authMiddleware, getGroupExpensesHandler);

// ── GET /api/expenses/me ──────────────────────────────────────────
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
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
    return res.status(500).json({ error: 'Failed to fetch expenses' });
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
    return res.json({ expense: enriched[0] });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update expense' });
  }
});

// ── DELETE /api/expenses/:expenseId ──────────────────────────────
router.delete('/:expenseId', authMiddleware, async (req, res) => {
  try {
    await sql`DELETE FROM expenses WHERE id = ${req.params.expenseId} AND paid_by = ${req.user.userId}`;
    return res.json({ message: 'Expense deleted' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to delete expense' });
  }
});

export default router;
