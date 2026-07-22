#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const projectId = 'brisconnect-68b78';
const rulesPath = path.join(__dirname, '../firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║  FIRESTORE RULES DEPLOYMENT (Admin SDK)                       ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

async function deployRules() {
  try {
    // Try to initialize with Application Default Credentials
    console.log('📋 Initializing Firebase Admin SDK...');
    
    // Check for service account file in common locations
    const potentialPaths = [
      process.env.GOOGLE_APPLICATION_CREDENTIALS,
      path.join(process.env.HOME || '', '.config/gcloud/application_default_credentials.json'),
      path.join(process.env.HOME || '', '.config/gcloud/legacy_credentials'),
    ].filter(Boolean);

    let initialized = false;
    let credentialSource = 'unknown';

    // Try to find and use available credentials
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
      console.log('Using GOOGLE_APPLICATION_CREDENTIALS...');
      const serviceAccount = JSON.parse(
        fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')
      );
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId
      });
      initialized = true;
      credentialSource = 'service account file';
    } else {
      // Try Application Default Credentials
      try {
        admin.initializeApp({
          projectId
        });
        initialized = true;
        credentialSource = 'Application Default Credentials (ADC)';
      } catch (err) {
        console.log('⚠️  ADC not available, trying alternative methods...');
      }
    }

    if (!initialized) {
      throw new Error(
        'Cannot initialize Firebase Admin SDK without credentials.\n' +
        'Please set GOOGLE_APPLICATION_CREDENTIALS environment variable to your service account JSON file.\n' +
        'Or authenticate with gcloud: gcloud auth application-default login'
      );
    }

    console.log(`✓ Initialized using: ${credentialSource}\n`);

    // Attempt to deploy rules using the Firestore API
    console.log('⏳ Deploying Firestore Security Rules...\n');
    
    // Using the admin SDK's internal method to deploy rules (if available)
    // Otherwise, we'll need to use a REST API call
    
    try {
      // Try using the Firestore native interface
      const firestoreAdmin = admin.firestore();
      
      // Unfortunately, firebase-admin doesn't expose rules deployment directly
      // We need to use the REST API instead
      throw new Error('Admin SDK does not directly support rules deployment');
    } catch (e) {
      // Fall back to REST API
      console.log('Using Firestore Rules REST API...\n');
      
      const result = await deployViaRestAPI();
      if (result) {
        console.log('✓ Rules deployed successfully!\n');
        seedData();
      }
    }

  } catch (err) {
    console.error('\n✗ Deployment failed:', err.message);
    console.error('\n💡 Alternative solution: Use a service account\n');
    console.error('To set up service account authentication:');
    console.error('1. Go to: https://console.firebase.google.com/project/brisconnect-68b78/settings/serviceaccounts/adminsdk');
    console.error('2. Click "Generate New Private Key"');
    console.error('3. Save the JSON file');
    console.error('4. Set environment variable:');
    console.error('   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"');
    console.error('5. Run this script again\n');
    
    process.exit(1);
  }
}

async function deployViaRestAPI() {
  return new Promise((resolve, reject) => {
    // Get the authentication token from the Admin SDK
    admin.app().auth().getAccessToken()
      .then(tokenResult => {
        const token = tokenResult.access_token;
        
        const payload = {
          source: {
            files: [
              {
                content: rules,
                name: 'firestore.rules'
              }
            ]
          }
        };

        const options = {
          hostname: 'firestore.googleapis.com',
          path: `/v1/projects/${projectId}/rulesets`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          }
        };

        const req = require('https').request(options, (res) => {
          let data = '';
          res.on('data', chunk => { data += chunk; });
          res.on('end', () => {
            if (res.statusCode === 200 || res.statusCode === 201) {
              const response = JSON.parse(data);
              const rulesetId = response.name.split('/').pop();
              
              // Now release the ruleset
              releaseRuleset(rulesetId, token, resolve, reject);
            } else {
              reject(new Error(`API returned status ${res.statusCode}: ${data}`));
            }
          });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
      })
      .catch(reject);
  });
}

async function releaseRuleset(rulesetId, token, resolve, reject) {
  const payload = {
    name: `projects/${projectId}/rulesets/${rulesetId}`
  };

  const options = {
    hostname: 'firestore.googleapis.com',
    path: `/v1/projects/${projectId}/releases/firestore`,
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      'X-Goog-FieldMask': 'rulesetId'
    }
  };

  const req = require('https').request(options, (res) => {
    let data = '';
    res.on('data', chunk => { data += chunk; });
    res.on('end', () => {
      if (res.statusCode === 200) {
        resolve(true);
      } else {
        reject(new Error(`Release failed with status ${res.statusCode}: ${data}`));
      }
    });
  });

  req.on('error', reject);
  req.write(JSON.stringify(payload));
  req.end();
}

async function seedData() {
  console.log('✓ Rules deployed! Now seeding 27 Brisbane food businesses...\n');
  
  // Run the seed script
  const seedScript = require.resolve('./seed_brisbane_cbd_rest.js');
  const { spawn } = require('child_process');
  
  const child = spawn('node', [seedScript], {
    stdio: 'inherit',
    cwd: __dirname
  });

  child.on('error', (err) => {
    console.error('Seed error:', err);
  });

  child.on('close', (code) => {
    process.exit(code);
  });
}

// Run deployment
deployRules().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
