import express from 'express';
import jwt from 'jsonwebtoken';
import { sql } from '../db.js';

const router = express.Router();

function formatUser(u) {
  if (!u) return null;
  return {
    id: u.id,
    name: u.name,
    email: u.email,
    avatarId: u.avatar_id || u.avatarId || 'avatar_1',
    avatar_id: u.avatar_id || u.avatarId || 'avatar_1',
    currency: u.currency || 'INR',
    createdAt: u.created_at || u.createdAt,
    updatedAt: u.updated_at || u.updatedAt,
  };
}

// ── Auth Middleware ───────────────────────────────────────────────
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization required' });
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// ── GET /api/users/me ─────────────────────────────────────────────
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const users = await sql`
      SELECT id, name, email, avatar_id, currency, created_at, updated_at
      FROM users WHERE id = ${req.user.userId}
    `;

    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ user: formatUser(users[0]) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// ── PATCH /api/users/me ───────────────────────────────────────────
router.patch('/me', authMiddleware, async (req, res) => {
  try {
    const { name, avatar_id, avatarId, currency } = req.body;
    const targetAvatar = avatar_id || avatarId;

    const users = await sql`
      UPDATE users SET
        name = COALESCE(${name ?? null}, name),
        avatar_id = COALESCE(${targetAvatar ?? null}, avatar_id),
        currency = COALESCE(${currency ?? null}, currency),
        updated_at = NOW()
      WHERE id = ${req.user.userId}
      RETURNING id, name, email, avatar_id, currency, created_at, updated_at
    `;

    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ user: formatUser(users[0]) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to update profile' });
  }
});

// ── GET /api/users/search?email= ─────────────────────────────────
router.get('/search', authMiddleware, async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email query is required' });

    const users = await sql`
      SELECT id, name, email, avatar_id
      FROM users
      WHERE email ILIKE ${`%${email}%`}
      AND id != ${req.user.userId}
      LIMIT 10
    `;

    return res.json({ users: users.map(formatUser) });
  } catch (err) {
    return res.status(500).json({ error: 'Search failed' });
  }
});

// ── POST /api/users/devices ───────────────────────────────────────
router.post('/devices', authMiddleware, async (req, res) => {
  const { fcmToken, deviceType } = req.body;
  console.log(`📱 Received device registration request. User: ${req.user.userId}, Device: ${deviceType}, Token: ${fcmToken ? fcmToken.substring(0, 15) : 'null'}...`);
  
  if (!fcmToken) {
    console.warn(`⚠️ Device registration failed: FCM token is missing.`);
    return res.status(400).json({ error: 'FCM token is required' });
  }

  try {
    await sql`
      INSERT INTO user_devices (user_id, fcm_token, device_type)
      VALUES (${req.user.userId}, ${fcmToken}, ${deviceType || 'android'})
      ON CONFLICT (fcm_token) 
      DO UPDATE SET user_id = ${req.user.userId}, updated_at = NOW()
    `;
    console.log(`✅ Device token registered successfully in database for user: ${req.user.userId}`);
    return res.status(200).json({ message: 'Device token registered successfully' });
  } catch (err) {
    console.error('❌ FCM registration error:', err);
    return res.status(500).json({ error: 'Failed to register device' });
  }
});

// ── DELETE /api/users/devices ─────────────────────────────────────
router.delete('/devices', authMiddleware, async (req, res) => {
  const fcmToken = req.body.fcmToken || req.query.fcmToken;
  if (!fcmToken) {
    return res.status(400).json({ error: 'FCM token is required' });
  }

  try {
    await sql`
      DELETE FROM user_devices 
      WHERE user_id = ${req.user.userId} AND fcm_token = ${fcmToken}
    `;
    return res.json({ message: 'Device token removed successfully' });
  } catch (err) {
    console.error('FCM removal error:', err);
    return res.status(500).json({ error: 'Failed to remove device' });
  }
});

// ── DELETE /api/users/me ───────────────────────────────────────────
router.delete('/me', authMiddleware, async (req, res) => {
  const userId = req.user.userId;
  console.log(`🗑️ Processing account deletion request for user: ${userId}`);

  try {
    // 1. Delete user device tokens
    await sql`DELETE FROM user_devices WHERE user_id = ${userId}`;

    // 2. Delete user notifications
    await sql`DELETE FROM notifications WHERE user_id = ${userId}`;

    // 3. Delete user invitations
    await sql`DELETE FROM group_invitations WHERE sender_id = ${userId} OR receiver_id = ${userId}`;

    // 4. Delete settlements involving this user (as sender or receiver)
    await sql`DELETE FROM settlements WHERE from_user = ${userId} OR to_user = ${userId}`;

    // 5. Delete expense participant records for this user
    await sql`DELETE FROM expense_participants WHERE user_id = ${userId}`;

    // 6. Delete expenses paid by this user (and their participants first)
    const userExpenses = await sql`SELECT id FROM expenses WHERE paid_by = ${userId}`;
    if (userExpenses.length > 0) {
      const expIds = userExpenses.map(e => e.id);
      await sql`DELETE FROM expense_participants WHERE expense_id = ANY(${expIds})`;
      await sql`DELETE FROM expenses WHERE paid_by = ${userId}`;
    }

    // 7. Remove user from group memberships
    await sql`DELETE FROM group_members WHERE user_id = ${userId}`;

    // 8. Delete user account record
    await sql`DELETE FROM users WHERE id = ${userId}`;

    console.log(`✅ Account deleted successfully for user: ${userId}`);
    return res.json({ message: 'Account deleted successfully' });
  } catch (err) {
    console.error('❌ Account deletion error:', err);
    return res.status(500).json({ error: 'Failed to delete account' });
  }
});

export default router;
export { authMiddleware };
