import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { getGroupExpensesHandler } from './expenses.js';
import { getGroupSettlementsHandler } from './settlements.js';
import { emitToUser, emitToGroup } from '../index.js';

const router = express.Router();

function formatMember(m) {
  return {
    id: m.id || `${m.group_id || m.groupId}-${m.user_id || m.userId}`,
    groupId: m.group_id || m.groupId,
    userId: m.user_id || m.userId,
    joinedAt: m.joined_at || m.joinedAt,
    user: m.user
      ? {
          id: m.user.id,
          name: m.user.name,
          email: m.user.email,
          avatarId: m.user.avatarId || m.user.avatar_id || 'avatar_1',
        }
      : m.name
      ? {
          id: m.user_id || m.userId,
          name: m.name,
          email: m.email,
          avatarId: m.avatar_id || m.avatarId || 'avatar_1',
        }
      : null,
  };
}

function formatGroupInvitation(gi) {
  return {
    id: gi.id,
    groupId: gi.group_id || gi.groupId,
    groupName: gi.group_name || gi.groupName,
    senderId: gi.sender_id || gi.senderId,
    senderName: gi.sender_name || gi.senderName,
    receiverId: gi.receiver_id || gi.receiverId,
    receiverName: gi.receiver_name || gi.receiverName,
    receiverEmail: gi.receiver_email || gi.receiverEmail,
    receiverAvatarId: gi.receiver_avatar_id || gi.receiverAvatarId || 'avatar_1',
    status: gi.status,
    createdAt: gi.created_at || gi.createdAt,
    updatedAt: gi.updated_at || gi.updatedAt,
  };
}

function formatGroup(g, members = [], invitations = []) {
  return {
    id: g.id,
    name: g.name,
    description: g.description,
    createdBy: g.created_by || g.createdBy,
    createdAt: g.created_at || g.createdAt,
    updatedAt: g.updated_at || g.updatedAt,
    totalExpenses: parseFloat(g.total_expenses || g.totalExpenses || 0),
    myBalance: parseFloat(g.my_balance || g.myBalance || 0),
    members: members.map(formatMember),
    invitations: invitations.map(formatGroupInvitation),
  };
}

// ── GET /api/groups ───────────────────────────────────────────────
router.get('/', authMiddleware, async (req, res) => {
  try {
    const groups = await sql`
      SELECT
        g.id,
        g.name,
        g.description,
        g.created_by,
        g.created_at,
        g.updated_at,
        COALESCE(
          (SELECT SUM(e.amount) FROM expenses e WHERE e.group_id = g.id),
          0
        ) AS total_expenses,
        (
          COALESCE(
            (SELECT SUM(amount) FROM expenses WHERE group_id = g.id AND paid_by = ${req.user.userId}),
            0
          ) - COALESCE(
            (SELECT SUM(ep.share_amount) FROM expense_participants ep JOIN expenses e ON ep.expense_id = e.id WHERE e.group_id = g.id AND ep.user_id = ${req.user.userId}),
            0
          ) + COALESCE(
            (SELECT SUM(amount) FROM settlements WHERE group_id = g.id AND from_user = ${req.user.userId} AND status = 'completed'),
            0
          ) - COALESCE(
            (SELECT SUM(amount) FROM settlements WHERE group_id = g.id AND to_user = ${req.user.userId} AND status = 'completed'),
            0
          )
        ) AS my_balance
      FROM groups g
      JOIN group_members gm ON g.id = gm.group_id
      WHERE gm.user_id = ${req.user.userId}
      ORDER BY g.updated_at DESC
    `;

    const groupIds = groups.map(g => g.id);
    const members = groupIds.length > 0 ? await sql`
      SELECT gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
      FROM group_members gm
      JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ANY(${groupIds})
    ` : [];

    const enriched = groups.map(g =>
      formatGroup(
        g,
        members.filter(m => m.group_id === g.id)
      )
    );

    return res.json({ groups: enriched });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch groups' });
  }
});

// ── POST /api/groups ──────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name?.trim()) return res.status(400).json({ error: 'Group name is required' });

    const groupId = uuidv4();

    const groups = await sql`
      INSERT INTO groups (id, name, description, created_by)
      VALUES (${groupId}, ${name.trim()}, ${description?.trim() || null}, ${req.user.userId})
      RETURNING *
    `;

    // Auto-add creator as member
    const memberId = uuidv4();
    await sql`
      INSERT INTO group_members (id, group_id, user_id)
      VALUES (${memberId}, ${groupId}, ${req.user.userId})
    `;

    const creatorUser = await sql`SELECT id, name, email, avatar_id FROM users WHERE id = ${req.user.userId}`;

    const creatorMember = {
      id: memberId,
      groupId: groupId,
      userId: req.user.userId,
      joinedAt: new Date().toISOString(),
      user: {
        id: creatorUser[0].id,
        name: creatorUser[0].name,
        email: creatorUser[0].email,
        avatarId: creatorUser[0].avatar_id,
      },
    };

    const group = formatGroup(groups[0], [creatorMember]);
    return res.status(201).json({ group });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to create group' });
  }
});

// ── GET /api/groups/:groupId ──────────────────────────────────────
router.get('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;

    const membership = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    if (membership.length === 0) {
      return res.status(403).json({ error: 'Not a member of this group' });
    }

    const groups = await sql`
      SELECT
        g.id,
        g.name,
        g.description,
        g.created_by,
        g.created_at,
        g.updated_at,
        COALESCE(
          (SELECT SUM(e.amount) FROM expenses e WHERE e.group_id = g.id),
          0
        ) AS total_expenses,
        (
          COALESCE(
            (SELECT SUM(amount) FROM expenses WHERE group_id = g.id AND paid_by = ${req.user.userId}),
            0
          ) - COALESCE(
            (SELECT SUM(ep.share_amount) FROM expense_participants ep JOIN expenses e ON ep.expense_id = e.id WHERE e.group_id = g.id AND ep.user_id = ${req.user.userId}),
            0
          ) + COALESCE(
            (SELECT SUM(amount) FROM settlements WHERE group_id = g.id AND from_user = ${req.user.userId} AND status = 'completed'),
            0
          ) - COALESCE(
            (SELECT SUM(amount) FROM settlements WHERE group_id = g.id AND to_user = ${req.user.userId} AND status = 'completed'),
            0
          )
        ) AS my_balance
      FROM groups g
      WHERE g.id = ${groupId}
    `;
    if (groups.length === 0) return res.status(404).json({ error: 'Group not found' });

    const members = await sql`
      SELECT gm.id, gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
      FROM group_members gm
      JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ${groupId}
    `;

    const invitations = await sql`
      SELECT gi.*, g.name AS group_name, u_sender.name AS sender_name, u_rec.name AS receiver_name, u_rec.email AS receiver_email, u_rec.avatar_id AS receiver_avatar_id
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      JOIN users u_sender ON gi.sender_id = u_sender.id
      JOIN users u_rec ON gi.receiver_id = u_rec.id
      WHERE gi.group_id = ${groupId}
    `;

    const group = formatGroup(groups[0], members, invitations);
    return res.json({ group });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch group' });
  }
});

// ── GET /api/groups/:groupId/expenses ─────────────────────────────
router.get('/:groupId/expenses', authMiddleware, getGroupExpensesHandler);

// ── GET /api/groups/:groupId/settlements ──────────────────────────
router.get('/:groupId/settlements', authMiddleware, getGroupSettlementsHandler);

// ── PUT /api/groups/:groupId ──────────────────────────────────────
router.put('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { name, description } = req.body;

    const groups = await sql`
      UPDATE groups SET
        name = COALESCE(${name ?? null}, name),
        description = COALESCE(${description ?? null}, description),
        updated_at = NOW()
      WHERE id = ${groupId} AND created_by = ${req.user.userId}
      RETURNING *
    `;

    if (groups.length === 0) return res.status(404).json({ error: 'Group not found or not authorized' });

    const group = formatGroup(groups[0]);
    return res.json({ group });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to update group' });
  }
});

// ── DELETE /api/groups/:groupId ───────────────────────────────────
router.delete('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const result = await sql`
      DELETE FROM groups WHERE id = ${groupId} AND created_by = ${req.user.userId} RETURNING id
    `;
    if (result.length === 0) return res.status(404).json({ error: 'Group not found or not authorized' });

    emitToGroup(groupId, 'realtime_update', { type: 'group_deleted', groupId });
    return res.json({ message: 'Group deleted successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to delete group' });
  }
});

// ── POST /api/groups/:groupId/leave ───────────────────────────────
router.post('/:groupId/leave', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    await sql`
      DELETE FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    emitToGroup(groupId, 'realtime_update', { type: 'member_left', groupId, userId: req.user.userId });
    return res.json({ message: 'Left group successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to leave group' });
  }
});

// ── POST /api/groups/:groupId/members ─────────────────────────────
router.post('/:groupId/members', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { email } = req.body;

    if (!email?.trim()) return res.status(400).json({ error: 'User email is required' });

    const targetUsers = await sql`SELECT id, name, email FROM users WHERE LOWER(email) = LOWER(${email.trim()})`;
    if (targetUsers.length === 0) return res.status(404).json({ error: 'User with this email not found' });

    const receiver = targetUsers[0];
    if (receiver.id === req.user.userId) return res.status(400).json({ error: 'Cannot invite yourself' });

    const existingMember = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${receiver.id}
    `;
    if (existingMember.length > 0) return res.status(400).json({ error: 'User is already a member of this group' });

    const existingInv = await sql`
      SELECT 1 FROM group_invitations WHERE group_id = ${groupId} AND receiver_id = ${receiver.id} AND status = 'pending'
    `;
    if (existingInv.length > 0) return res.status(400).json({ error: 'Invitation already pending for this user' });

    const invitationId = uuidv4();
    await sql`
      INSERT INTO group_invitations (id, group_id, sender_id, receiver_id, status)
      VALUES (${invitationId}, ${groupId}, ${req.user.userId}, ${receiver.id}, 'pending')
    `;

    const groups = await sql`SELECT name FROM groups WHERE id = ${groupId}`;
    const groupName = groups[0]?.name || 'a group';
    const senderUser = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
    const senderName = senderUser[0]?.name || 'Someone';

    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${receiver.id},
        'Group Invitation',
        ${`${senderName} invited you to join "${groupName}"`},
        'group_invitation',
        ${groupId}
      )
    `;

    emitToUser(receiver.id, 'realtime_update', { type: 'invitation_received', groupId, invitationId });
    emitToGroup(groupId, 'realtime_update', { type: 'invitation_sent', groupId });

    return res.status(201).json({ message: 'Invitation sent successfully', invitationId });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to add member' });
  }
});

export default router;
