import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { emitToGroup, emitToUser } from '../index.js';

const router = express.Router();

function formatInvitation(gi) {
  return {
    id: gi.id,
    groupId: gi.group_id || gi.groupId,
    groupName: gi.group_name || gi.groupName,
    senderId: gi.sender_id || gi.senderId,
    senderName: gi.sender_name || gi.senderName,
    senderAvatarId: gi.sender_avatar_id || gi.senderAvatarId || 'avatar_1',
    receiverId: gi.receiver_id || gi.receiverId,
    receiverName: gi.receiver_name || gi.receiverName,
    receiverEmail: gi.receiver_email || gi.receiverEmail,
    receiverAvatarId: gi.receiver_avatar_id || gi.receiverAvatarId || 'avatar_1',
    status: gi.status,
    createdAt: gi.created_at || gi.createdAt,
    updatedAt: gi.updated_at || gi.updatedAt,
  };
}

// ── GET /api/invitations/pending ──────────────────────────────────
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    const invitations = await sql`
      SELECT
        gi.id,
        gi.group_id,
        gi.sender_id,
        gi.receiver_id,
        gi.status,
        gi.created_at,
        gi.updated_at,
        g.name AS group_name,
        u_sender.name AS sender_name,
        u_sender.avatar_id AS sender_avatar_id
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      JOIN users u_sender ON gi.sender_id = u_sender.id
      WHERE gi.receiver_id = ${req.user.userId} AND gi.status = 'pending'
      ORDER BY gi.created_at DESC
    `;

    return res.json({ invitations: invitations.map(formatInvitation) });
  } catch (err) {
    console.error('Fetch pending invitations error:', err);
    return res.status(500).json({ error: 'Failed to fetch pending invitations' });
  }
});

// ── POST /api/invitations/:invitationId/accept ───────────────────
router.post('/:invitationId/accept', authMiddleware, async (req, res) => {
  try {
    const { invitationId } = req.params;

    const existing = await sql`
      SELECT gi.*, g.name AS group_name
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      WHERE gi.id = ${invitationId} AND gi.receiver_id = ${req.user.userId}
    `;

    if (existing.length === 0) {
      return res.status(404).json({ error: 'Invitation not found' });
    }

    const inv = existing[0];
    if (inv.status === 'accepted') {
      return res.status(400).json({ error: 'Invitation has already been accepted' });
    }

    // Update invitation status
    await sql`
      UPDATE group_invitations
      SET status = 'accepted', updated_at = NOW()
      WHERE id = ${invitationId}
    `;

    // Add user to group_members
    const memberId = uuidv4();
    await sql`
      INSERT INTO group_members (id, group_id, user_id)
      VALUES (${memberId}, ${inv.group_id}, ${req.user.userId})
      ON CONFLICT (group_id, user_id) DO NOTHING
    `;

    // Send notification to sender
    const receiverUser = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
    const receiverName = receiverUser[0]?.name || 'A user';
    const notifId = uuidv4();
    await sql`
      INSERT INTO notifications (id, user_id, title, message, type, reference_id)
      VALUES (
        ${notifId},
        ${inv.sender_id},
        'Invitation Accepted',
        ${`${receiverName} accepted your invitation to join "${inv.group_name}"`},
        'invitation_accepted',
        ${inv.group_id}
      )
    `;

    emitToGroup(inv.group_id, 'realtime_update', { type: 'invitation_accepted', groupId: inv.group_id, userId: req.user.userId });
    emitToUser(inv.sender_id, 'realtime_update', { type: 'invitation_accepted', groupId: inv.group_id, userId: req.user.userId });

    return res.json({ message: 'Invitation accepted successfully' });
  } catch (err) {
    console.error('Accept invitation error:', err);
    return res.status(500).json({ error: 'Failed to accept invitation' });
  }
});

// ── POST /api/invitations/:invitationId/decline ──────────────────
router.post('/:invitationId/decline', authMiddleware, async (req, res) => {
  try {
    const { invitationId } = req.params;

    const existing = await sql`
      SELECT * FROM group_invitations
      WHERE id = ${invitationId} AND receiver_id = ${req.user.userId}
    `;

    if (existing.length === 0) {
      return res.status(404).json({ error: 'Invitation not found' });
    }

    await sql`
      UPDATE group_invitations
      SET status = 'declined', updated_at = NOW()
      WHERE id = ${invitationId}
    `;

    emitToUser(existing[0].sender_id, 'realtime_update', { type: 'invitation_declined', groupId: existing[0].group_id });

    return res.json({ message: 'Invitation declined successfully' });
  } catch (err) {
    console.error('Decline invitation error:', err);
    return res.status(500).json({ error: 'Failed to decline invitation' });
  }
});

export default router;
