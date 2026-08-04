// broadcast.js
// Run this script via Node.js to trigger an update push notification to all users.
// Command: node broadcast.js <version> [message]
// Example: node broadcast.js 2.6.0 "A critical bug fix update is out!"

const http = require('http');
const https = require('https');

const args = process.argv.slice(2);
const version = args[0] || 'latest';
const message = args[1] || '';

// The secret must match ADMIN_SECRET in backend/routes/notifications.js
const ADMIN_SECRET = 'easysplit-admin-2026';
const BACKEND_URL = 'http://localhost:5000/api/notifications/broadcast-update'; // Change to production URL when deployed

const payload = JSON.stringify({
  secret: ADMIN_SECRET,
  version: version,
  message: message
});

const url = new URL(BACKEND_URL);
const client = url.protocol === 'https:' ? https : http;

const req = client.request(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload)
  }
}, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Response: ${data}`);
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.write(payload);
req.end();
