const fs = require('fs');
const https = require('https');
const jwt = require('jsonwebtoken');

async function deployRules() {
  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║  FIRESTORE RULES DEPLOYMENT - Firestore REST API               ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
    '/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json';
  
  if (!fs.existsSync(serviceAccountPath)) {
    console.error('✗ Service account key not found at:', serviceAccountPath);
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const projectId = serviceAccount.project_id;
  const now = Math.floor(Date.now() / 1000);

  // Create JWT token for service account
  console.log('🔐 Creating JWT token for service account...');
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const token = jwt.sign(payload, serviceAccount.private_key, { algorithm: 'RS256' });
  console.log('✓ JWT token created');

  // Exchange JWT for access token
  console.log('⏳ Exchanging JWT for access token...');
  const accessToken = await new Promise((resolve, reject) => {
    const URLSearchParams = require('url').URLSearchParams;
    const postData = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: token,
    }).toString();

    const options = {
      hostname: 'oauth2.googleapis.com',
      port: 443,
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.access_token) {
            console.log('✓ Access token obtained');
            resolve(parsed.access_token);
          } else {
            reject(new Error('No access token in response: ' + data));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });

  // Read the rules file
  console.log('📖 Reading firestore.rules file...');
  const rulesContent = fs.readFileSync('/Users/ibrahim_ahhoa/Documents/BrisConnect/firestore.rules', 'utf8');
  console.log('✓ Rules file read (' + rulesContent.length + ' bytes)');

  // Create a new ruleset
  console.log('⏳ Creating new ruleset...');
  const rulesetId = await new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      source: {
        files: [
          {
            name: 'firestore.rules',
            content: rulesContent,
          },
        ],
      },
    });

    const options = {
      hostname: 'firebaserules.googleapis.com',
      port: 443,
      path: `/v1/projects/${projectId}/rulesets`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        console.log('Create Ruleset Status:', res.statusCode);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            const parsed = JSON.parse(data);
            const rulesetName = parsed.name; // e.g., "projects/brisconnect-68b78/rulesets/abc123"
            console.log('✓ Ruleset created:', rulesetName);
            resolve(rulesetName);
          } catch (e) {
            reject(e);
          }
        } else {
          console.log('Response:', data);
          reject(new Error('Failed to create ruleset: ' + res.statusCode));
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });

  // Now release this ruleset to make it active for Firestore database
  console.log('⏳ Releasing ruleset to Firestore database...');
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      rulesetName: rulesetId,
    });

    const options = {
      hostname: 'firebaserules.googleapis.com',
      port: 443,
      path: `/v1/projects/${projectId}/releases/firestore.rules`,
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        console.log('Release Status:', res.statusCode);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log('✓ Rules released successfully!');
          resolve(true);
        } else {
          console.log('Response:', data);
          console.log('\nℹ️  Attempting alternative release method...');
          // Fallback: try using POST to create a release
          const postCreateData = JSON.stringify({
            name: `projects/${projectId}/releases/firestore.rules`,
            rulesetName: rulesetId,
          });

          const createOptions = {
            hostname: 'firebaserules.googleapis.com',
            port: 443,
            path: `/v1/projects/${projectId}/releases`,
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(postCreateData),
            },
          };

          const createReq = https.request(createOptions, (createRes) => {
            let createData = '';
            createRes.on('data', (chunk) => { createData += chunk; });
            createRes.on('end', () => {
              console.log('Create Release Status:', createRes.statusCode);
              if (createRes.statusCode >= 200 && createRes.statusCode < 300) {
                console.log('✓ Rules released successfully via create method!');
                resolve(true);
              } else {
                console.log('Create Response:', createData);
                reject(new Error('Release failed with both methods'));
              }
            });
          });

          createReq.on('error', reject);
          createReq.write(postCreateData);
          createReq.end();
        }
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

deployRules()
  .then(() => {
    console.log('\n✅ Firestore rules deployment complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Deployment failed:', error.message);
    process.exit(1);
  });
