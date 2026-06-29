import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { emitToGroup, emitToUser } from '../index.js';

const router = express.Router();

// Auto-migration check on startup for extra columns
(async () => {
  try {
    await sql`ALTER TABLE settlements ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'UPI'`;
    await sql`ALTER TABLE settlements ADD COLUMN IF NOT EXISTS note TEXT`;
    await sql`ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check`;
  } catch (e) {
    console.log('Migration note:', e.message);
  }
})();

function formatSettlement(s) {
  return {
    id: s.id,
    fromUser: s.from_user || s.fromUser,
    toUser: s.to_user || s.toUser,
    groupId: s.group_id || s.groupId,
    amount: parseFloat(s.amount),
    paymentMethod: s.payment_method || s.paymentMethod || 'UPI',
    note: s.note,
    status: s.status,
    settledAt: s.settled_at || s.settledAt,
    createdAt: s.created_at || s.createdAt,
    fromUserName: s.from_user_name || s.fromUserName,
    toUserName: s.to_user_name || s.toUserName,
    fromUserAvatar: s.from_user_avatar || s.fromUserAvatar || 'avatar_1',
    toUserAvatar: s.to_user_avatar || s.toUserAvatar || 'avatar_1',
  };
}

// ── GET /api/settlements/me ───────────────────────────────────────
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const settlements = await sql`
      SELECT
        s.*,
        fu.name AS from_user_name, fu.avatar_id AS from_user_avatar,
        tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.from_user = ${req.user.userId} OR s.to_user = ${req.user.userId}
      ORDER BY s.created_at DESC
    `;

    return res.json({ settlements: settlements.map(formatSettlement) });
  } catch (err) {
    console.error('Fetch settlements error:', err);
    return res.status(500).json({ error: 'Failed to fetch settlements' });
  }
});

// ── GET /api/groups/:groupId/settlements ──────────────────────────
export async function getGroupSettlementsHandler(req, res) {
  try {
    const settlements = await sql`
      SELECT
        s.*,
        fu.name AS from_user_name, fu.avatar_id AS from_user_avatar,
        tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.group_id = ${req.params.groupId}
      ORDER BY s.created_at DESC
    `;

    return res.json({ settlements: settlements.map(formatSettlement) });
  } catch (err) {
    console.error('Fetch group settlements error:', err);
    return res.status(500).json({ error: 'Failed to fetch settlements' });
  }
}

router.get('/groups/:groupId/settlements', authMiddleware, getGroupSettlementsHandler);
router.get('/:groupId/settlements', authMiddleware, getGroupSettlementsHandler);

// ── POST /api/settlements ─────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { to_user, toUser, group_id, groupId, amount, payment_method, paymentMethod, note } = req.body;
    const targetToUser = to_user || toUser;
    const targetGroupId = group_id || groupId;
    const targetMethod = payment_method || paymentMethod || 'UPI';

    if (targetGroupId) {
      const groupCheck = await sql`SELECT is_locked FROM groups WHERE id = ${targetGroupId}`;
      if (groupCheck.length > 0 && groupCheck[0].is_locked) {
        return res.status(403).json({ error: 'This group is finalized and locked. Recording settlements is disabled.' });
      }
    }

    if (!targetToUser || !amount || parseFloat(amount) <= 0) {
      return res.status(400).json({ error: 'Valid receiver and amount are required' });
    }

    const settlementId = uuidv4();
    await sql`
      INSERT INTO settlements (id, from_user, to_user, group_id, amount, payment_method, note, status)
      VALUES (
        ${settlementId},
        ${req.user.userId},
        ${targetToUser},
        ${targetGroupId || null},
        ${parseFloat(amount)},
        ${targetMethod},
        ${note || null},
        'pending'
      )
    `;

    const settlements = await sql`
      SELECT s.*, fu.name AS from_user_name, fu.avatar_id AS from_user_avatar, tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.id = ${settlementId}
    `;

    const formatted = formatSettlement(settlements[0]);

    // Notify receiver about pending settlement
    const payerUser = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
    const payerName = payerUser[0]?.name || 'A group member';
    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${targetToUser},
        'Payment Marked as Paid',
        ${`${payerName} marked ₹${parseFloat(amount).toFixed(2)} as paid via ${targetMethod}. Please confirm receiving this payment.`},
        'settlement_reminder',
        ${targetGroupId || null}
      )
    `;

    if (targetGroupId) emitToGroup(targetGroupId, 'realtime_update', { type: 'settlement_created', groupId: targetGroupId, settlement: formatted });
    emitToUser(targetToUser, 'realtime_update', { type: 'settlement_created', settlement: formatted });

    return res.status(201).json({ settlement: formatted });
  } catch (err) {
    console.error('Create settlement error:', err);
    return res.status(500).json({ error: 'Failed to create settlement' });
  }
});

// ── PATCH /api/settlements/:settlementId/confirm ──────────────────
router.patch('/:settlementId/confirm', authMiddleware, async (req, res) => {
  try {
    const { settlementId } = req.params;

    const settlements = await sql`
      UPDATE settlements
      SET status = 'completed', settled_at = NOW()
      WHERE id = ${settlementId} AND to_user = ${req.user.userId}
      RETURNING *
    `;

    if (settlements.length === 0) {
      return res.status(404).json({ error: 'Settlement not found or only receiver can confirm payment' });
    }

    const enriched = await sql`
      SELECT s.*, fu.name AS from_user_name, fu.avatar_id AS from_user_avatar, tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.id = ${settlementId}
    `;

    const formatted = formatSettlement(enriched[0]);

    // Notify payer
    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${formatted.fromUser},
        'Payment Confirmed',
        ${`${formatted.toUserName} confirmed receiving your payment of ₹${formatted.amount.toFixed(2)}.`},
        'settlement_completed',
        ${formatted.groupId || null}
      )
    `;

    if (formatted.groupId) emitToGroup(formatted.groupId, 'realtime_update', { type: 'settlement_updated', groupId: formatted.groupId, settlement: formatted });
    emitToUser(formatted.fromUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });
    emitToUser(formatted.toUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });

    return res.json({ settlement: formatted });
  } catch (err) {
    console.error('Confirm settlement error:', err);
    return res.status(500).json({ error: 'Failed to confirm settlement' });
  }
});

router.patch('/:settlementId/settle', authMiddleware, async (req, res) => {
  // Alias for backward compatibility
  return router.handle({ ...req, url: `/${req.params.settlementId}/confirm`, method: 'PATCH' }, res);
});

// ── PATCH /api/settlements/:settlementId/reject ───────────────────
router.patch('/:settlementId/reject', authMiddleware, async (req, res) => {
  try {
    const { settlementId } = req.params;

    const settlements = await sql`
      UPDATE settlements
      SET status = 'rejected', settled_at = NOW()
      WHERE id = ${settlementId} AND to_user = ${req.user.userId}
      RETURNING *
    `;

    if (settlements.length === 0) {
      return res.status(404).json({ error: 'Settlement not found or only receiver can reject payment' });
    }

    const enriched = await sql`
      SELECT s.*, fu.name AS from_user_name, fu.avatar_id AS from_user_avatar, tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.id = ${settlementId}
    `;

    const formatted = formatSettlement(enriched[0]);

    // Notify payer
    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${formatted.fromUser},
        'Payment Rejected',
        ${`${formatted.toUserName} marked your payment of ₹${formatted.amount.toFixed(2)} as rejected.`},
        'settlement_reminder',
        ${formatted.groupId || null}
      )
    `;

    if (formatted.groupId) emitToGroup(formatted.groupId, 'realtime_update', { type: 'settlement_updated', groupId: formatted.groupId, settlement: formatted });
    emitToUser(formatted.fromUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });
    emitToUser(formatted.toUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });

    return res.json({ settlement: formatted });
  } catch (err) {
    console.error('Reject settlement error:', err);
    return res.status(500).json({ error: 'Failed to reject settlement' });
  }
});

export default router;
