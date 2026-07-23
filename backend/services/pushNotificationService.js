import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { sql } from '../db.js';

// Initialize Firebase Admin (Requires Firebase Service Account credentials loaded as JSON in env)
let isFirebaseInitialized = false;

try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } catch (parseErr) {
      // If it is not valid JSON, it might be a base64 encoded string or a file path
      console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT env variable is not valid JSON. Checking Base64 or path...');
      try {
        serviceAccount = JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8'));
      } catch (b64Err) {
        // Assume it might be a file path
        serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
      }
    }

    if (typeof serviceAccount === 'object' && serviceAccount.private_key) {
      serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
    }

    initializeApp({
      credential: typeof serviceAccount === 'object' 
        ? cert(serviceAccount) 
        : applicationDefault()
    });
    isFirebaseInitialized = true;
    console.log('🔥 Firebase Admin SDK initialized successfully.');
  } else {
    console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT environment variable is not set. Push notifications are disabled.');
  }
} catch (err) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', err);
}

/**
 * Sends a push notification to all registered devices of a user
 * @param {string} userId - Target user ID
 * @param {object} payload - Notification payload { title, body, data }
 */
export async function sendPushNotification(userId, { title, body, data = {} }) {
  if (!isFirebaseInitialized) {
    console.log(`[Push Notification Mock] To User: ${userId} | Title: "${title}" | Body: "${body}"`);
    return;
  }

  try {
    // 1. Fetch active devices for the user
    const devices = await sql`
      SELECT fcm_token FROM user_devices WHERE user_id = ${userId}
    `;

    if (devices.length === 0) {
      console.log(`ℹ️ No registered devices found for user ${userId}.`);
      return;
    }

    const tokens = devices.map(d => d.fcm_token);

    // 2. Prepare message payload (ensure all data values are string)
    const stringifiedData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined && value !== null) {
        stringifiedData[key] = String(value);
      }
    }

    const message = {
      notification: { title, body },
      data: stringifiedData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
          sound: 'default',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
      tokens,
    };

    // 3. Send multicast message
    console.log(`📤 Sending push notification to ${tokens.length} devices of user ${userId}...`);
    const messaging = getMessaging();
    const response = await messaging.sendEachForMulticast(message);
    
    // 4. Handle invalid/stale tokens
    const tokensToRemove = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        console.warn(`⚠️ Failed to deliver push to token: ${tokens[idx].substring(0, 15)}... Error code: ${error?.code || error?.message}`);
        if (error?.code === 'messaging/invalid-registration-token' ||
            error?.code === 'messaging/registration-token-not-registered') {
          tokensToRemove.push(tokens[idx]);
        }
      } else {
        console.log(`✅ Push delivered successfully to device token: ${tokens[idx].substring(0, 15)}...`);
      }
    });

    // 5. Clean up expired tokens
    if (tokensToRemove.length > 0) {
      console.log(`🧹 Removing ${tokensToRemove.length} inactive device tokens from database.`);
      await sql`
        DELETE FROM user_devices WHERE fcm_token = ANY(${tokensToRemove})
      `;
    }
  } catch (error) {
    console.error('❌ Error sending push notifications:', error);
  }
}
