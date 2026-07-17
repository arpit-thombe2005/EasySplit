import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { getGroupExpensesHandler } from './expenses.js';
import { getGroupSettlementsHandler } from './settlements.js';
import { emitToUser, emitToGroup } from '../index.js';
import { generateGroupExcelReport } from '../services/excelGenerator.js';
import { generateGroupPdfReport } from '../services/pdfGenerator.js';
import { sendGroupBackupEmail } from '../services/emailService.js';
import { getGroupAnalytics } from '../services/analyticsService.js';
import { sendPushNotification } from '../services/pushNotificationService.js';

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
    isLocked: Boolean(g.is_locked || g.isLocked),
    isArchived: Boolean(g.is_archived || g.isArchived),
    createdAt: g.created_at || g.createdAt,
    updatedAt: g.updated_at || g.updatedAt,
    totalExpenses: parseFloat(g.total_expenses || g.totalExpenses || 0),
    myBalance: parseFloat(g.my_balance || g.myBalance || 0),
    members: members.map(formatMember),
    invitations: invitations.map(formatGroupInvitation),
  };
}

async function fetchGroupFullData(groupId) {
  const groups = await sql`SELECT * FROM groups WHERE id = ${groupId}`;
  if (groups.length === 0) return null;
  const group = groups[0];

  const members = await sql`
    SELECT gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
    FROM group_members gm
    JOIN users u ON gm.user_id = u.id
    WHERE gm.group_id = ${groupId}
  `;

  const rawExpenses = await sql`
    SELECT e.*, u.name AS paid_by_name
    FROM expenses e
    JOIN users u ON e.paid_by = u.id
    WHERE e.group_id = ${groupId}
    ORDER BY e.created_at DESC
  `;

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

  const settlements = await sql`
    SELECT s.*, fu.name AS from_user_name, tu.name AS to_user_name
    FROM settlements s
    JOIN users fu ON s.from_user = fu.id
    JOIN users tu ON s.to_user = tu.id
    WHERE s.group_id = ${groupId}
    ORDER BY s.created_at DESC
  `;

  return { group, members, expenses, settlements };
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
        g.is_locked,
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

    const groupIds = groups.map((g) => g.id);
    const members = groupIds.length > 0 ? await sql`
      SELECT gm.group_id, gm.user_id, gm.joined_at, u.name, u.email, u.avatar_id
      FROM group_members gm
      JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ANY(${groupIds})
    ` : [];

    const enriched = groups.map((g) =>
      formatGroup(
        g,
        members.filter((m) => m.group_id === g.id)
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
      INSERT INTO groups (id, name, description, created_by, is_locked)
      VALUES (${groupId}, ${name.trim()}, ${description?.trim() || null}, ${req.user.userId}, FALSE)
      RETURNING *
    `;

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

// ── GET /api/groups/:groupId/analytics ────────────────────────────
router.get('/:groupId/analytics', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { filter, startDate, endDate } = req.query;

    const membership = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    if (membership.length === 0) return res.status(403).json({ error: 'Not a member of this group' });

    const analytics = await getGroupAnalytics({ groupId, filter, startDate, endDate });
    if (!analytics) return res.status(404).json({ error: 'Group not found' });

    return res.json({ analytics });
  } catch (err) {
    console.error('Analytics error:', err);
    return res.status(500).json({ error: 'Failed to generate group analytics' });
  }
});

// ── GET /api/groups/:groupId/export ──────────────────────────────
router.get('/:groupId/export', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const membership = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    if (membership.length === 0) return res.status(403).json({ error: 'Not a member of this group' });

    const data = await fetchGroupFullData(groupId);
    if (!data) return res.status(404).json({ error: 'Group not found' });

    const excelBuffer = await generateGroupExcelReport(data);
    const cleanName = data.group.name.replace(/[^a-zA-Z0-9]/g, '');
    const dateStr = new Date().toISOString().split('T')[0];
    const filename = `EasySplit_${cleanName}_${dateStr}.xlsx`;

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    // Send push notification that reports are ready to other members
    (async () => {
      try {
        const members = await sql`
          SELECT user_id FROM group_members WHERE group_id = ${groupId} AND user_id != ${req.user.userId}
        `;
        const exporterUser = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
        const exporterName = exporterUser[0]?.name || 'A group member';
        
        for (const m of members) {
          const notifId = uuidv4();
          await sql`
            INSERT INTO notifications (id, user_id, title, message, type, reference_id)
            VALUES (
              ${notifId},
              ${m.user_id},
              'Group Reports Ready',
              ${`${exporterName} generated Excel reports for "${data.group.name}".`},
              'reports_ready',
              ${groupId}
            )
          `;
          sendPushNotification(m.user_id, {
            title: `Reports Ready in ${data.group.name}`,
            body: `${exporterName} generated the group Excel expense reports.`,
            data: {
              type: 'reports_ready',
              groupId: groupId,
              referenceId: notifId
            }
          });
        }
      } catch (err) {
        console.error('Failed to send Excel reports ready push notification:', err);
      }
    })();

    return res.send(excelBuffer);
  } catch (err) {
    console.error('Export Excel error:', err);
    return res.status(500).json({ error: 'Failed to export group expenses as Excel' });
  }
});

// ── GET /api/groups/:groupId/export-pdf ──────────────────────────
router.get('/:groupId/export-pdf', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const membership = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    if (membership.length === 0) return res.status(403).json({ error: 'Not a member of this group' });

    const data = await fetchGroupFullData(groupId);
    if (!data) return res.status(404).json({ error: 'Group not found' });

    const pdfBuffer = await generateGroupPdfReport(data);
    const cleanName = data.group.name.replace(/[^a-zA-Z0-9]/g, '');
    const dateStr = new Date().toISOString().split('T')[0];
    const filename = `EasySplit_${cleanName}_${dateStr}.pdf`;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    // Send push notification that reports are ready to other members
    (async () => {
      try {
        const members = await sql`
          SELECT user_id FROM group_members WHERE group_id = ${groupId} AND user_id != ${req.user.userId}
        `;
        const exporterUser = await sql`SELECT name FROM users WHERE id = ${req.user.userId}`;
        const exporterName = exporterUser[0]?.name || 'A group member';
        
        for (const m of members) {
          const notifId = uuidv4();
          await sql`
            INSERT INTO notifications (id, user_id, title, message, type, reference_id)
            VALUES (
              ${notifId},
              ${m.user_id},
              'Group Reports Ready',
              ${`${exporterName} generated PDF reports for "${data.group.name}".`},
              'reports_ready',
              ${groupId}
            )
          `;
          sendPushNotification(m.user_id, {
            title: `Reports Ready in ${data.group.name}`,
            body: `${exporterName} generated the group PDF expense reports.`,
            data: {
              type: 'reports_ready',
              groupId: groupId,
              referenceId: notifId
            }
          });
        }
      } catch (err) {
        console.error('Failed to send PDF reports ready push notification:', err);
      }
    })();

    return res.send(pdfBuffer);
  } catch (err) {
    console.error('Export PDF error:', err);
    return res.status(500).json({ error: 'Failed to export group expenses as PDF' });
  }
});

// ── GET /api/groups/:groupId ──────────────────────────────────────
router.get('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;

    const membership = await sql`
      SELECT 1 FROM group_members WHERE group_id = ${groupId} AND user_id = ${req.user.userId}
    `;
    if (membership.length === 0) return res.status(403).json({ error: 'Not a member of this group' });

    const groups = await sql`
      SELECT
        g.id,
        g.name,
        g.description,
        g.created_by,
        g.is_locked,
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

// ── PATCH/PUT /api/groups/:groupId/lock ──────────────────────────
const handleLockToggle = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { isLocked } = req.body;

    const groupCheck = await sql`SELECT created_by FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length === 0) return res.status(404).json({ error: 'Group not found' });
    if (groupCheck[0].created_by !== req.user.userId) {
      return res.status(403).json({ error: 'Only the group owner can lock or unlock this group' });
    }

    const updated = await sql`
      UPDATE groups
      SET is_locked = ${Boolean(isLocked)}, updated_at = NOW()
      WHERE id = ${groupId}
      RETURNING *
    `;

    const group = formatGroup(updated[0]);
    emitToGroup(groupId, 'realtime_update', { type: isLocked ? 'group_locked' : 'group_unlocked', groupId });

    if (isLocked) {
      (async () => {
        try {
          const members = await sql`
            SELECT user_id FROM group_members WHERE group_id = ${groupId} AND user_id != ${req.user.userId}
          `;
          for (const m of members) {
            const notifId = uuidv4();
            await sql`
              INSERT INTO notifications (id, user_id, title, message, type, reference_id)
              VALUES (
                ${notifId},
                ${m.user_id},
                'Group Locked',
                ${`The group "${group.name}" has been locked and finalized by the owner.`},
                'group_locked',
                ${groupId}
              )
            `;
            sendPushNotification(m.user_id, {
              title: 'Group Locked & Finalized',
              body: `The group "${group.name}" has been locked and finalized by the owner.`,
              data: {
                type: 'group_locked',
                groupId: groupId,
                referenceId: notifId
              }
            });
          }
        } catch (notifErr) {
          console.error('Failed to send group locked notifications:', notifErr);
        }
      })();
    }

    return res.json({ group, message: `Group ${isLocked ? 'locked' : 'unlocked'} successfully` });
  } catch (err) {
    console.error('Lock group error:', err);
    return res.status(500).json({ error: 'Failed to update group lock state' });
  }
};
router.patch('/:groupId/lock', authMiddleware, handleLockToggle);
router.put('/:groupId/lock', authMiddleware, handleLockToggle);

// ── PATCH/PUT /api/groups/:groupId/archive ───────────────────────
const handleArchiveToggle = async (req, res) => {
  try {
    const { groupId } = req.params;
    const { isArchived } = req.body;

    const groupCheck = await sql`SELECT created_by, name FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length === 0) return res.status(404).json({ error: 'Group not found' });
    if (groupCheck[0].created_by !== req.user.userId) {
      return res.status(403).json({ error: 'Only the group owner can archive or unarchive this group' });
    }

    const updated = await sql`
      UPDATE groups
      SET is_archived = ${Boolean(isArchived)}, updated_at = NOW()
      WHERE id = ${groupId}
      RETURNING *
    `;

    const group = formatGroup(updated[0]);
    emitToGroup(groupId, 'realtime_update', { type: isArchived ? 'group_archived' : 'group_unarchived', groupId });

    // Send push notification when group is archived/unarchived
    (async () => {
      try {
        const members = await sql`
          SELECT user_id FROM group_members WHERE group_id = ${groupId} AND user_id != ${req.user.userId}
        `;
        const actionText = isArchived ? 'archived' : 'unarchived';
        for (const m of members) {
          const notifId = uuidv4();
          await sql`
            INSERT INTO notifications (id, user_id, title, message, type, reference_id)
            VALUES (
              ${notifId},
              ${m.user_id},
              ${`Group ${isArchived ? 'Archived' : 'Unarchived'}`},
              ${`The group "${group.name}" has been ${actionText} by the owner.`},
              ${isArchived ? 'group_archived' : 'group_unarchived'},
              ${groupId}
            )
          `;
          sendPushNotification(m.user_id, {
            title: `Group ${isArchived ? 'Archived' : 'Unarchived'}`,
            body: `The group "${group.name}" has been ${actionText} by the owner.`,
            data: {
              type: isArchived ? 'group_archived' : 'group_unarchived',
              groupId: groupId,
              referenceId: notifId
            }
          });
        }
      } catch (notifErr) {
        console.error('Failed to send group archive notifications:', notifErr);
      }
    })();

    return res.json({ group, message: `Group ${isArchived ? 'archived' : 'unarchived'} successfully` });
  } catch (err) {
    console.error('Archive group error:', err);
    return res.status(500).json({ error: 'Failed to update group archive state' });
  }
};
router.patch('/:groupId/archive', authMiddleware, handleArchiveToggle);
router.put('/:groupId/archive', authMiddleware, handleArchiveToggle);

// ── PUT /api/groups/:groupId ──────────────────────────────────────
router.put('/:groupId', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { name, description } = req.body;

    const groupCheck = await sql`SELECT is_locked FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length > 0 && groupCheck[0].is_locked) {
      return res.status(403).json({ error: 'This group is finalized and locked. Editing is disabled.' });
    }

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

    const groupCheck = await sql`SELECT created_by, name FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length === 0) return res.status(404).json({ error: 'Group not found' });
    if (groupCheck[0].created_by !== req.user.userId) {
      return res.status(403).json({ error: 'Only the group owner can permanently delete this group' });
    }

    const data = await fetchGroupFullData(groupId);
    if (!data) return res.status(404).json({ error: 'Group not found' });

    // Step 1: Generate Excel and PDF reports
    const excelBuffer = await generateGroupExcelReport(data);
    const pdfBuffer = await generateGroupPdfReport(data);
    const cleanName = data.group.name.replace(/[^a-zA-Z0-9]/g, '');
    const dateStr = new Date().toISOString().split('T')[0];
    const excelFilename = `EasySplit_${cleanName}_${dateStr}.xlsx`;
    const pdfFilename = `EasySplit_${cleanName}_${dateStr}.pdf`;

    // Step 2: Queue email delivery with BOTH attachments in background
    data.members.forEach((m) => {
      const email = m.email || m.user?.email;
      if (email) {
        sendGroupBackupEmail({
          toEmail: email,
          groupName: data.group.name,
          excelBuffer,
          pdfBuffer,
          excelFilename,
          pdfFilename,
        }).catch((err) => {
          console.error(`Failed to send backup email to ${email}:`, err);
        });
      }
    });

    // Step 3: Permanently delete group and notify active rooms
    await sql`DELETE FROM groups WHERE id = ${groupId}`;

    emitToGroup(groupId, 'realtime_update', { type: 'group_deleted', groupId });
    return res.json({ message: 'Group deleted and backup reports queued successfully' });
  } catch (err) {
    console.error('Delete group workflow error:', err);
    return res.status(500).json({ error: 'Failed to execute delete group workflow' });
  }
});

// ── POST /api/groups/:groupId/leave ───────────────────────────────
router.post('/:groupId/leave', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupCheck = await sql`SELECT is_locked FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length > 0 && groupCheck[0].is_locked) {
      return res.status(403).json({ error: 'This group is finalized and locked. Members cannot leave.' });
    }

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

// ── Group Invitation / Member Routes ──────────────────────────────
async function handleCreateInvitation(req, res) {
  try {
    const { groupId } = req.params;
    const { email } = req.body;

    const groupCheck = await sql`SELECT is_locked FROM groups WHERE id = ${groupId}`;
    if (groupCheck.length > 0 && groupCheck[0].is_locked) {
      return res.status(403).json({ error: 'This group is finalized and locked. Inviting new members is disabled.' });
    }

    if (!email?.trim()) return res.status(400).json({ error: 'User email is required' });

    const targetUsers = await sql`SELECT id, name, email, avatar_id FROM users WHERE LOWER(email) = LOWER(${email.trim()})`;
    if (targetUsers.length === 0) return res.status(404).json({ error: 'This email is not registered on EasySplit' });

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
    const inserted = await sql`
      INSERT INTO group_invitations (id, group_id, sender_id, receiver_id, status)
      VALUES (${invitationId}, ${groupId}, ${req.user.userId}, ${receiver.id}, 'pending')
      RETURNING *
    `;

    const groups = await sql`SELECT name FROM groups WHERE id = ${groupId}`;
    const groupName = groups[0]?.name || 'a group';
    const senderUser = await sql`SELECT name, avatar_id FROM users WHERE id = ${req.user.userId}`;
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

    // Trigger FCM Push notification
    sendPushNotification(receiver.id, {
      title: 'Group Invitation',
      body: `${senderName} invited you to join "${groupName}"`,
      data: {
        type: 'group_invitation',
        referenceId: groupId,
        invitationId
      }
    });

    emitToUser(receiver.id, 'realtime_update', { type: 'invitation_received', groupId, invitationId });
    emitToGroup(groupId, 'realtime_update', { type: 'invitation_sent', groupId });

    const invitationObj = formatGroupInvitation({
      ...inserted[0],
      group_name: groupName,
      sender_name: senderName,
      sender_avatar_id: senderUser[0]?.avatar_id,
      receiver_name: receiver.name,
      receiver_email: receiver.email,
      receiver_avatar_id: receiver.avatar_id,
    });

    const mockMember = formatMember({
      id: `${groupId}-${receiver.id}`,
      group_id: groupId,
      user_id: receiver.id,
      joined_at: new Date().toISOString(),
      user: receiver,
    });

    return res.status(201).json({
      message: 'Invitation sent successfully',
      invitationId,
      invitation: invitationObj,
      member: mockMember,
    });
  } catch (err) {
    console.error('Create invitation error:', err);
    return res.status(500).json({ error: 'Failed to send invitation' });
  }
}

router.post('/:groupId/invitations', authMiddleware, handleCreateInvitation);
router.post('/:groupId/members', authMiddleware, handleCreateInvitation);

router.get('/:groupId/invitations', authMiddleware, async (req, res) => {
  try {
    const { groupId } = req.params;
    const invitations = await sql`
      SELECT gi.*, g.name AS group_name, u_sender.name AS sender_name, u_sender.avatar_id AS sender_avatar_id, u_rec.name AS receiver_name, u_rec.email AS receiver_email, u_rec.avatar_id AS receiver_avatar_id
      FROM group_invitations gi
      JOIN groups g ON gi.group_id = g.id
      JOIN users u_sender ON gi.sender_id = u_sender.id
      JOIN users u_rec ON gi.receiver_id = u_rec.id
      WHERE gi.group_id = ${groupId}
      ORDER BY gi.created_at DESC
    `;
    return res.json({ invitations: invitations.map(formatGroupInvitation) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch group invitations' });
  }
});

router.post('/:groupId/invitations/:invitationId/resend', authMiddleware, async (req, res) => {
  try {
    const { groupId, invitationId } = req.params;
    await sql`UPDATE group_invitations SET updated_at = NOW() WHERE id = ${invitationId} AND group_id = ${groupId}`;
    emitToGroup(groupId, 'realtime_update', { type: 'invitation_resent', groupId, invitationId });
    return res.json({ message: 'Invitation resent successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to resend invitation' });
  }
});

router.delete('/:groupId/invitations/:invitationId', authMiddleware, async (req, res) => {
  try {
    const { groupId, invitationId } = req.params;
    await sql`DELETE FROM group_invitations WHERE id = ${invitationId} AND group_id = ${groupId}`;
    emitToGroup(groupId, 'realtime_update', { type: 'invitation_cancelled', groupId, invitationId });
    return res.json({ message: 'Invitation cancelled successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to cancel invitation' });
  }
});

export default router;
