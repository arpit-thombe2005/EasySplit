import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { getGroupExpensesHandler } from './expenses.js';
import { getGroupSettlementsHandler } from './settlements.js';

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

    const groups = await sql`SELECT * FROM groups WHERE id = ${groupId}`;
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

    if (groups.length === 0) {
      return res.status(403).json({ error: 'Not authorized to edit this group' });
    }

    const members = await sql`
      SELECT gm.id, gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
      FROM group_members gm
      JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ${groupId}
    `;

    return res.json({ group: formatGroup(groups[0], members) });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update group' });
  }
});

// ── DELETE /api/groups/:groupId ───────────────────────────────────
router.delete('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;

    const result = await sql`
      DELETE FROM groups WHERE id = ${groupId} AND created_by = ${req.user.userId}
      RETURNING id
    `;

    if (result.length === 0) {
      return res.status(403).json({ error: 'Not authorized to delete this group' });
    }

    return res.json({ message: 'Group deleted' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to delete group' });
  }
});

// ── Invitation Handler Function ───────────────────────────────────
async function createInvitationHandler(req, res) {
  try {
    const { groupId } = req.params;
    const { email } = req.body;

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!email || !emailRegex.test(email.trim())) {
      return res.status(400).json({ error: 'Please enter a valid email address' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Check whether user exists in users table
    const users = await sql`SELECT id, name FROM users WHERE email = ${cleanEmail}`;
    if (users.length === 0) {
      return res.status(404).json({ error: 'No account found with this email.' });
    }

    const targetUserId = users[0].id;

    // Check whether user is already a member
    const existingMember = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${targetUserId}
    `;
    if (existingMember.length > 0) {
      return res.status(409).json({ error: 'This user is already a member of this group.' });
    }

    // Check existing invitation
    const existingInv = await sql`
      SELECT id, status FROM group_invitations WHERE group_id = ${groupId} AND receiver_id = ${targetUserId}
    `;

    if (existingInv.length > 0) {
      if (existingInv[0].status === 'pending') {
        return res.status(409).json({ error: 'An invitation has already been sent to this user.' });
      }
    }

    // Get group info and sender info
    const groupRows = await sql`SELECT name FROM groups WHERE id = ${groupId}`;
    if (groupRows.length === 0) return res.status(404).json({ error: 'Group not found' });
    const groupName = groupRows[0].name;

    const senderRows = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
    const senderName = senderRows[0]?.name || 'Someone';

    let invId;
    if (existingInv.length > 0) {
      // Re-inviting a user whose invitation was declined
      invId = existingInv[0].id;
      await sql`
        UPDATE group_invitations
        SET status = 'pending', sender_id = ${req.user.userId}, updated_at = NOW()
        WHERE id = ${invId}
      `;
    } else {
      invId = uuidv4();
      await sql`
        INSERT INTO group_invitations (id, group_id, sender_id, receiver_id, status)
        VALUES (${invId}, ${groupId}, ${req.user.userId}, ${targetUserId}, 'pending')
      `;
    }

    // Create in-app notification
    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${targetUserId},
        'Group Invitation',
        ${`${senderName} invited you to join the group "${groupName}"`},
        'group_invitation',
        ${invId}
      )
    `;

    const resultInv = await sql`
      SELECT gi.*, g.name AS group_name, u_sender.name AS sender_name, u_rec.name AS receiver_name, u_rec.email AS receiver_email, u_rec.avatar_id AS receiver_avatar_id
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      JOIN users u_sender ON gi.sender_id = u_sender.id
      JOIN users u_rec ON gi.receiver_id = u_rec.id
      WHERE gi.id = ${invId}
    `;

    return res.status(201).json({
      message: 'Invitation sent successfully',
      invitation: formatGroupInvitation(resultInv[0]),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to send invitation' });
  }
}

// ── POST /api/groups/:groupId/members & /invitations ───────────────
router.post('/:groupId/members', authMiddleware, createInvitationHandler);
router.post('/:groupId/invitations', authMiddleware, createInvitationHandler);

// ── GET /api/groups/:groupId/invitations ─────────────────────────
router.get('/:groupId/invitations', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const invitations = await sql`
      SELECT gi.*, g.name AS group_name, u_sender.name AS sender_name, u_rec.name AS receiver_name, u_rec.email AS receiver_email, u_rec.avatar_id AS receiver_avatar_id
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      JOIN users u_sender ON gi.sender_id = u_sender.id
      JOIN users u_rec ON gi.receiver_id = u_rec.id
      WHERE gi.group_id = ${groupId}
      ORDER BY gi.updated_at DESC
    `;
    return res.json({ invitations: invitations.map(formatGroupInvitation) });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch group invitations' });
  }
});

// ── POST /api/groups/:groupId/invitations/:invitationId/resend ────
router.post('/:groupId/invitations/:invitationId/resend', authMiddleware, async (req, res) => {
  try {
    const { groupId, invitationId } = req.params;

    const existing = await sql`
      SELECT gi.*, g.name AS group_name
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      WHERE gi.id = ${invitationId} AND gi.group_id = ${groupId}
    `;

    if (existing.length === 0) return res.status(404).json({ error: 'Invitation not found' });
    const inv = existing[0];

    await sql`
      UPDATE group_invitations
      SET status = 'pending', sender_id = ${req.user.userId}, updated_at = NOW()
      WHERE id = ${invitationId}
    `;

    const senderRows = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
    const senderName = senderRows[0]?.name || 'Someone';
    const notifId = uuidv4();

    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${inv.receiver_id},
        'Group Invitation',
        ${`${senderName} invited you to join the group "${inv.group_name}"`},
        'group_invitation',
        ${inv.id}
      )
    `;

    return res.json({ message: 'Invitation resent successfully' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to resend invitation' });
  }
});

// ── DELETE /api/groups/:groupId/invitations/:invitationId ─────────
router.delete('/:groupId/invitations/:invitationId', authMiddleware, async (req, res) => {
  try {
    const { groupId, invitationId } = req.params;
    await sql`
      DELETE FROM group_invitations
      WHERE id = ${invitationId} AND group_id = ${groupId}
    `;
    return res.json({ message: 'Invitation cancelled' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to cancel invitation' });
  }
});


// ── DELETE /api/groups/:groupId/members/:userId ───────────────────
router.delete('/:groupId/members/:userId', authMiddleware, async (req, res) => {
  try {
    const { groupId, userId } = req.params;

    await sql`
      DELETE FROM group_members
      WHERE group_id = ${groupId} AND user_id = ${userId}
    `;

    return res.json({ message: 'Member removed' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to remove member' });
  }
});

// ── POST /api/groups/:groupId/leave ──────────────────────────────
router.post('/:groupId/leave', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;

    await sql`
      DELETE FROM group_members
      WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;

    return res.json({ message: 'Left group successfully' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to leave group' });
  }
});

// ── GET /api/groups/:groupId/debts/simplified ─────────────────────
router.get('/:groupId/debts/simplified', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;

    const expenses = await sql`
      SELECT e.id, e.paid_by, e.amount, ep.user_id, ep.share_amount
      FROM expenses e
      JOIN expense_participants ep ON e.id = ep.expense_id
      WHERE e.group_id = ${groupId}
    `;

    const settlements = await sql`
      SELECT from_user, to_user, amount
      FROM settlements
      WHERE group_id = ${groupId} AND status = 'completed'
    `;

    const balances = {};
    for (const exp of expenses) {
      balances[exp.paid_by] = (balances[exp.paid_by] || 0) + parseFloat(exp.amount);
      balances[exp.user_id] = (balances[exp.user_id] || 0) - parseFloat(exp.share_amount);
    }
    for (const s of settlements) {
      balances[s.from_user] = (balances[s.from_user] || 0) + parseFloat(s.amount);
      balances[s.to_user] = (balances[s.to_user] || 0) - parseFloat(s.amount);
    }

    const creditors = [];
    const debtors = [];
    for (const [userId, bal] of Object.entries(balances)) {
      if (bal > 0.01) creditors.push({ userId, amount: bal });
      else if (bal < -0.01) debtors.push({ userId, amount: -bal });
    }

    creditors.sort((a, b) => b.amount - a.amount);
    debtors.sort((a, b) => b.amount - a.amount);

    const debts = [];
    let ci = 0, di = 0;
    while (ci < creditors.length && di < debtors.length) {
      const transfer = Math.min(creditors[ci].amount, debtors[di].amount);
      debts.push({
        fromUserId: debtors[di].userId,
        toUserId: creditors[ci].userId,
        amount: parseFloat(transfer.toFixed(2)),
      });
      creditors[ci].amount -= transfer;
      debtors[di].amount -= transfer;
      if (creditors[ci].amount < 0.01) ci++;
      if (debtors[di].amount < 0.01) di++;
    }

    const userIds = [...new Set(debts.flatMap(d => [d.fromUserId, d.toUserId]))];
    const users = userIds.length > 0 ? await sql`
      SELECT id, name FROM users WHERE id = ANY(${userIds})
    ` : [];

    const userMap = Object.fromEntries(users.map(u => [u.id, u.name]));
    const enriched = debts.map(d => ({
      ...d,
      fromUserName: userMap[d.fromUserId] || d.fromUserId,
      toUserName: userMap[d.toUserId] || d.toUserId,
    }));

    return res.json({ debts: enriched });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to calculate debts' });
  }
});

export default router;
