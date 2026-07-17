import express from 'express';
import { runReminders } from '../services/scheduler.js';

const router = express.Router();

router.get('/version', (req, res) => {
  res.json({
    minimumVersion: process.env.APP_MIN_VERSION || '1.0.0',
    latestVersion: process.env.APP_LATEST_VERSION || '1.0.0',
    updateUrl: process.env.APP_UPDATE_URL || 'https://easysplit-p6z9.onrender.com',
  });
});

router.post('/run-reminders', async (req, res) => {
  try {
    await runReminders();
    res.json({ message: 'Reminder scheduler run executed successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to execute reminders' });
  }
});

export default router;
