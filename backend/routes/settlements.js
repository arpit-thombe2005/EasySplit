import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { emitToGroup, emitToUser } from '../index.js';

const router = express.Router();

function formatSettlement(s) {
  return {
    id: s.id,
    fromUser: s.from_user || s.fromUser,
    toUser: s.to_user || s.toUser,
    groupId: s.group_id || s.groupId,
    amount: parseFloat(s.amount),
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
    return res.status(500).json({ error: 'Failed to fetch settlements' });
  }
}

router.get('/groups/:groupId/settlements', authMiddleware, getGroupSettlementsHandler);
router.get('/:groupId/settlements', authMiddleware, getGroupSettlementsHandler);

// ── POST /api/settlements ─────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { to_user, toUser, group_id, groupId, amount } = req.body;
    const targetToUser = to_user || toUser;
    const targetGroupId = group_id || groupId;

    if (!targetToUser || !amount) {
      return res.status(400).json({ error: 'toUser and amount are required' });
    }

    const settlementId = uuidv4();
    await sql`
      INSERT INTO settlements (id, from_user, to_user, group_id, amount, status)
      VALUES (${settlementId}, ${req.user.userId}, ${targetToUser}, ${targetGroupId || null}, ${parseFloat(amount)}, 'pending')
    `;

    const settlements = await sql`
      SELECT s.*, fu.name AS from_user_name, fu.avatar_id AS from_user_avatar, tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.id = ${settlementId}
    `;

    const formatted = formatSettlement(settlements[0]);
    if (targetGroupId) emitToGroup(targetGroupId, 'realtime_update', { type: 'settlement_created', groupId: targetGroupId, settlement: formatted });
    emitToUser(targetToUser, 'realtime_update', { type: 'settlement_created', settlement: formatted });

    return res.status(201).json({ settlement: formatted });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to create settlement' });
  }
});

// ── PATCH /api/settlements/:settlementId/settle ───────────────────
router.patch('/:settlementId/settle', authMiddleware, async (req, res) => {
  try {
    const { settlementId } = req.params;

    const settlements = await sql`
      UPDATE settlements
      SET status = 'completed', settled_at = NOW()
      WHERE id = ${settlementId}
        AND (from_user = ${req.user.userId} OR to_user = ${req.user.userId})
      RETURNING *
    `;

    if (settlements.length === 0) {
      return res.status(404).json({ error: 'Settlement not found or not authorized' });
    }

    const enriched = await sql`
      SELECT s.*, fu.name AS from_user_name, fu.avatar_id AS from_user_avatar, tu.name AS to_user_name, tu.avatar_id AS to_user_avatar
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN users tu ON s.to_user = tu.id
      WHERE s.id = ${settlementId}
    `;

    const formatted = formatSettlement(enriched[0]);
    if (formatted.groupId) emitToGroup(formatted.groupId, 'realtime_update', { type: 'settlement_updated', groupId: formatted.groupId, settlement: formatted });
    emitToUser(formatted.fromUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });
    emitToUser(formatted.toUser, 'realtime_update', { type: 'settlement_updated', settlement: formatted });

    return res.json({ settlement: formatted });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to settle' });
  }
});

export default router;
