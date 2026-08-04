import express from 'express';
import { sql } from '../db.js';
import { authMiddleware } from './users.js';
import { sendPushNotification } from '../services/pushNotificationService.js';

const router = express.Router();

// ── POST /api/notifications/test-push ──────────────────────────────
router.post('/test-push', authMiddleware, async (req, res) => {
  try {
    await sendPushNotification(req.user.userId, {
      title: 'Test Push Notification',
      body: 'If you see this, push notifications are working perfectly!',
      data: { type: 'test' }
    });
    return res.json({ message: 'Test push notification sent successfully' });
  } catch (err) {
    console.error('Test push error:', err);
    return res.status(500).json({ error: 'Failed to send test push notification' });
  }
});

// ── GET /api/notifications ────────────────────────────────────────
router.get('/', authMiddleware, async (req, res) => {
  try {
    const notifications = await sql`
      SELECT * FROM notifications
      WHERE user_id = ${req.user.userId}
      ORDER BY created_at DESC
      LIMIT 50
    `;

    return res.json({ notifications });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

// ── PATCH /api/notifications/:id/read ─────────────────────────────
router.patch('/:id/read', authMiddleware, async (req, res) => {
  try {
    await sql`
      UPDATE notifications
      SET is_read = true
      WHERE id = ${req.params.id} AND user_id = ${req.user.userId}
    `;
    return res.json({ message: 'Notification marked as read' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update notification' });
  }
});

// ── PATCH /api/notifications/read-all ─────────────────────────────
router.patch('/read-all', authMiddleware, async (req, res) => {
  try {
    await sql`
      UPDATE notifications SET is_read = true WHERE user_id = ${req.user.userId}
    `;
    return res.json({ message: 'All notifications marked as read' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update notifications' });
  }
});

// ── POST /api/notifications/broadcast-update ──────────────────────
router.post('/broadcast-update', async (req, res) => {
  const { secret, version, message } = req.body;
  
  // Basic security check (you can change this secret or pass it in .env)
  const ADMIN_SECRET = process.env.ADMIN_SECRET || 'easysplit-admin-2026';
  if (secret !== ADMIN_SECRET) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  try {
    const devices = await sql`SELECT DISTINCT user_id FROM user_devices WHERE fcm_token IS NOT NULL`;
    
    let successCount = 0;
    const bodyText = message || `A new update (v${version || 'latest'}) is available! Please update EasySplit to enjoy the latest features and bug fixes.`;
    
    // Send to all users who have registered a device
    for (const device of devices) {
      try {
        await sendPushNotification(device.user_id, {
          title: '🚀 App Update Available!',
          body: bodyText,
          data: { type: 'app_update', version: version || 'latest' }
        });
        successCount++;
      } catch (err) {
        console.error(`Failed to send update push to user ${device.user_id}:`, err.message);
      }
    }
    
    return res.json({ 
      message: 'Broadcast complete', 
      totalUsersTargeted: devices.length,
      successCount 
    });
  } catch (err) {
    console.error('Broadcast error:', err);
    return res.status(500).json({ error: 'Failed to broadcast update notification' });
  }
});

export default router;
