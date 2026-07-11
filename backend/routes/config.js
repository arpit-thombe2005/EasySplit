import express from 'express';

const router = express.Router();

router.get('/version', (req, res) => {
  res.json({
    minimumVersion: process.env.APP_MIN_VERSION || '1.0.0',
    latestVersion: process.env.APP_LATEST_VERSION || '1.0.0',
    updateUrl: process.env.APP_UPDATE_URL || 'https://easysplit-p6z9.onrender.com',
  });
});

export default router;
