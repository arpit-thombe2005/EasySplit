import express from 'express';
import nodemailer from 'nodemailer';
import jwt from 'jsonwebtoken';
import { sql } from '../db.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

// ── Nodemailer Transporter ────────────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '465'),
  secure: true, // Use SSL on port 465 for reliable cloud host delivery
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  tls: {
    rejectUnauthorized: false,
  },
});

// ── Helpers ───────────────────────────────────────────────────────

/** Generate a 6-digit OTP */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/** Generate JWT token */
function generateToken(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
}

async function sendOtpEmail(email, otp) {
  const senderEmail = process.env.SMTP_USER || 'arpitthombe2005@gmail.com';
  const mailOptions = {
    from: `EasySplit <${senderEmail}>`,
    to: email,
    subject: `${otp} is your EasySplit verification code`,
    html: `
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px; background: #fff;">
        <div style="text-align: center; margin-bottom: 32px;">
          <div style="display: inline-block; background: #0A0A0A; border-radius: 16px; padding: 12px 20px;">
            <span style="color: #fff; font-size: 20px; font-weight: 700; letter-spacing: -0.5px;">EasySplit</span>
          </div>
        </div>
        
        <h1 style="font-size: 24px; font-weight: 700; color: #0A0A0A; margin-bottom: 8px;">Your verification code</h1>
        <p style="color: #737373; font-size: 16px; margin-bottom: 32px;">
          Use this code to sign in to your EasySplit account. It expires in 10 minutes.
        </p>
        
        <div style="background: #F5F5F5; border-radius: 16px; padding: 32px; text-align: center; margin-bottom: 32px;">
          <span style="font-size: 48px; font-weight: 700; letter-spacing: 12px; color: #0A0A0A; font-family: monospace;">${otp}</span>
        </div>
        
        <p style="color: #A3A3A3; font-size: 14px;">
          If you didn't request this code, you can safely ignore this email.
        </p>
        
        <hr style="border: none; border-top: 1px solid #E5E5E5; margin: 32px 0;">
        <p style="color: #D4D4D4; font-size: 12px; text-align: center;">EasySplit — Smart Expense Splitting</p>
      </body>
      </html>
    `,
    text: `Your EasySplit verification code is: ${otp}\n\nThis code expires in 10 minutes.`,
  };

  const sendPromise = transporter.sendMail(mailOptions);
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('SMTP timeout')), 20000)
  );

  await Promise.race([sendPromise, timeoutPromise]);
}

// ── POST /api/auth/send-otp ───────────────────────────────────────
router.post('/send-otp', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Upsert OTP record (one OTP per email at a time)
    await sql`
      INSERT INTO otps (email, otp, expires_at)
      VALUES (${normalizedEmail}, ${otp}, ${expiresAt})
      ON CONFLICT (email) 
      DO UPDATE SET otp = ${otp}, expires_at = ${expiresAt}, created_at = NOW()
    `;

    try {
      await sendOtpEmail(normalizedEmail, otp);
    } catch (emailErr) {
      console.error(`⚠️ SMTP dispatch note for ${normalizedEmail}:`, emailErr.message);
    }
    console.log(`🔑 OTP generated for ${normalizedEmail}: ${otp}`);

    return res.json({ message: 'OTP sent successfully', email: normalizedEmail });
  } catch (err) {
    console.error('Send OTP error:', err);
    return res.status(500).json({ error: 'Failed to send OTP. Please try again.' });
  }
});

// ── POST /api/auth/verify-otp ─────────────────────────────────────
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Fetch OTP record
    const otpRecords = await sql`
      SELECT * FROM otps 
      WHERE email = ${normalizedEmail} AND expires_at > NOW()
      ORDER BY created_at DESC
      LIMIT 1
    `;

    if (otpRecords.length === 0) {
      return res.status(400).json({ error: 'OTP has expired. Request a new one.' });
    }

    const otpRecord = otpRecords[0];

    if (otpRecord.otp !== otp.trim()) {
      return res.status(400).json({ error: 'Invalid OTP. Please try again.' });
    }

    // OTP verified — delete it
    await sql`DELETE FROM otps WHERE email = ${normalizedEmail}`;

    // Find or create user
    let userRecords = await sql`
      SELECT * FROM users WHERE email = ${normalizedEmail}
    `;

    let user;
    if (userRecords.length === 0) {
      // New user — create with randomly assigned avatar_id
      const userId = uuidv4();
      const randomAvatarId = `avatar_${Math.floor(Math.random() * 16) + 1}`;
      const created = await sql`
        INSERT INTO users (id, email, avatar_id, currency)
        VALUES (${userId}, ${normalizedEmail}, ${randomAvatarId}, 'INR')
        RETURNING *
      `;
      user = created[0];
    } else {
      user = userRecords[0];
    }

    const token = generateToken(user.id);

    return res.json({
      message: 'OTP verified successfully',
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarId: user.avatar_id,
        avatar_id: user.avatar_id,
        currency: user.currency,
        createdAt: user.created_at,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    console.error('Verify OTP error:', err);
    return res.status(500).json({ error: 'Failed to verify OTP.' });
  }
});

// ── POST /api/auth/logout ─────────────────────────────────────────
router.post('/logout', (req, res) => {
  // JWT is stateless — client clears token
  // Optionally add a token blacklist here
  res.json({ message: 'Logged out successfully' });
});

export default router;
