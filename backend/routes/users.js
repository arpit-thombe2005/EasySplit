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

export default router;
export { authMiddleware };
