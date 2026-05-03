'use strict';
const https = require('https');
const fs = require('fs');
const path = require('path');

// ── Configuration ──────────────────────────────────────────────
// Set these via environment variables or a local .env file:
//   FIREBASE_PROJECT_ID   – your Firebase project ID
//   FIREBASE_ACCESS_TOKEN – a valid OAuth2 access token
//   DELETE_UIDS           – comma-separated list of UIDs to delete
//
// Alternatively, create a uids.json file in this directory:
//   ["uid1", "uid2", ...]
// ───────────────────────────────────────────────────────────────

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
const ACCESS_TOKEN = process.env.FIREBASE_ACCESS_TOKEN;

if (!PROJECT_ID || !ACCESS_TOKEN) {
  console.error(
    'Missing required env vars: FIREBASE_PROJECT_ID and FIREBASE_ACCESS_TOKEN.\n' +
    'Example:\n' +
    '  FIREBASE_PROJECT_ID=my-project FIREBASE_ACCESS_TOKEN=$(gcloud auth print-access-token) node delete_auth_users.js'
  );
  process.exit(1);
}

function post(hostname, path, data, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const isForm = typeof data === 'string';
    const body = isForm ? data : JSON.stringify(data);
    const headers = {
      'Content-Type': isForm ? 'application/x-www-form-urlencoded' : 'application/json',
      'Content-Length': Buffer.byteLength(body),
      ...extraHeaders,
    };
    const options = { hostname, path, method: 'POST', headers };
    const req = https.request(options, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve(JSON.parse(d)); } catch (e) { resolve(d); } });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function run() {
  const accessToken = ACCESS_TOKEN;

  // Load UIDs from env var or uids.json file
  let uids;
  if (process.env.DELETE_UIDS) {
    uids = process.env.DELETE_UIDS.split(',').map(u => u.trim()).filter(Boolean);
  } else {
    const uidsPath = path.join(__dirname, 'uids.json');
    if (!fs.existsSync(uidsPath)) {
      console.error(
        'No UIDs provided. Either set DELETE_UIDS env var or create uids.json in this directory.'
      );
      process.exit(1);
    }
    uids = JSON.parse(fs.readFileSync(uidsPath, 'utf8'));
  }

  if (!uids.length) {
    console.log('No UIDs to delete.');
    return;
  }

  console.log(`Deleting ${uids.length} account(s)...`);

  const delRes = await post(
    'identitytoolkit.googleapis.com',
    `/v1/projects/${PROJECT_ID}/accounts:batchDelete`,
    { localIds: uids, force: true },
    { Authorization: `Bearer ${accessToken}` }
  );

  if (delRes.errors && delRes.errors.length > 0) {
    console.error('Some deletions failed:', JSON.stringify(delRes.errors, null, 2));
  } else {
    console.log(`Successfully deleted ${uids.length} accounts.`);
  }
  console.log('Response:', JSON.stringify(delRes, null, 2));
}

run().catch(console.error);
