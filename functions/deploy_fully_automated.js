#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const https = require('https');
const { spawn } = require('child_process');

const projectId = 'brisconnect-68b78';
const rulesPath = path.join(__dirname, '../firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║  FIRESTORE RULES DEPLOYMENT - AUTOMATED SETUP                 ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

async function main() {
  try {
    // Step 1: Check for existing credentials
    const credsFile = await getOrCreateServiceAccount();
    
    if (!credsFile) {
      console.log('\n✗ Cannot proceed without service account credentials');
      process.exit(1);
    }

    // Step 2: Deploy rules
    await deployRulesWithCredentials(credsFile);
    
    // Step 3: Seed data
    await seedBrisbaneFood();

  } catch (err) {
    console.error('\n✗ Error:', err.message);
    process.exit(1);
  }
}

async function getOrCreateServiceAccount() {
  console.log('🔐 Checking for service account credentials...\n');

  // Check environment variable
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    if (fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
      console.log('✓ Found GOOGLE_APPLICATION_CREDENTIALS');
      return process.env.GOOGLE_APPLICATION_CREDENTIALS;
    }
  }

  // Check project directory
  const projectCredsPath = path.join(__dirname, '../service-account-key.json');
  if (fs.existsSync(projectCredsPath)) {
    console.log('✓ Found service account key in project');
    return projectCredsPath;
  }

  // Check home directory
  const homeCredsPath = path.join(process.env.HOME || '', '.firebase/service-account-key.json');
  if (fs.existsSync(homeCredsPath)) {
    console.log('✓ Found service account key in home directory');
    return homeCredsPath;
  }

  // Guide user to create one
  console.log('⚠️  No service account credentials found.\n');
  return await guidedServiceAccountSetup();
}

async function guidedServiceAccountSetup() {
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║  GUIDED SERVICE ACCOUNT SETUP (takes < 2 minutes)              ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  console.log('To deploy Firestore rules automatically, I need a Service Account key.\n');
  console.log('Steps to create one:\n');
  console.log('1. Open: https://console.firebase.google.com/project/brisconnect-68b78/settings/serviceaccounts/adminsdk');
  console.log('2. At the bottom, click "Generate New Private Key"');
  console.log('3. Save the JSON file to your computer');
  console.log('4. Run one of these commands:\n');
  console.log('   Option A - Set environment variable (one time):');
  console.log('   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"');
  console.log('   node functions/deploy_with_admin_sdk.js\n');
  console.log('   Option B - Copy key to project:');
  console.log('   cp /path/to/service-account-key.json /Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json');
  console.log('   node functions/deploy_with_admin_sdk.js\n');

  return new Promise((resolve) => {
    rl.question('Have you created and saved the service account key? (yes/no): ', (answer) => {
      if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
        rl.question('Enter the full path to your service account key JSON file: ', (filepath) => {
          if (fs.existsSync(filepath)) {
            console.log('✓ Key file found!');
            rl.close();
            resolve(filepath);
          } else {
            console.error('\n✗ File not found. Please check the path and try again.');
            rl.close();
            resolve(null);
          }
        });
      } else {
        console.log('\nPlease complete the steps above first, then run this script again.');
        rl.close();
        resolve(null);
      }
    });
  });
}

async function deployRulesWithCredentials(credsPath) {
  return new Promise((resolve, reject) => {
    console.log('\n⏳ Deploying Firestore Security Rules...\n');

    // Use gcloud if available with the credentials
    const env = Object.assign({}, process.env, {
      GOOGLE_APPLICATION_CREDENTIALS: credsPath
    });

    // Try using gcloud
    let deployed = false;

    // Method 1: Try gcloud
    const gcloud = spawn('gcloud', [
      'firestore:rules:deploy',
      rulesPath,
      `--project=${projectId}`
    ], { env, stdio: 'pipe' });

    let output = '';
    gcloud.stdout.on('data', (data) => {
      output += data;
      process.stdout.write(data);
    });
    gcloud.stderr.on('data', (data) => {
      output += data;
      process.stderr.write(data);
    });

    const timeout = setTimeout(() => {
      gcloud.kill();
    }, 30000);

    gcloud.on('close', (code) => {
      clearTimeout(timeout);
      if (code === 0) {
        console.log('\n✓ Rules deployed successfully via gcloud!');
        deployed = true;
        resolve();
      } else {
        // Try Firebase CLI as fallback
        console.log('\nTrying Firebase CLI...\n');
        tryFirebaseDeploy(credsPath, resolve, reject);
      }
    });

    gcloud.on('error', () => {
      console.log('gcloud not available, trying Firebase CLI...\n');
      tryFirebaseDeploy(credsPath, resolve, reject);
    });
  });
}

function tryFirebaseDeploy(credsPath, resolve, reject) {
  const env = Object.assign({}, process.env, {
    GOOGLE_APPLICATION_CREDENTIALS: credsPath
  });

  const firebase = spawn('firebase', [
    'deploy',
    '--only', 'firestore:rules',
    '--project', projectId
  ], { 
    env, 
    stdio: 'pipe',
    cwd: path.dirname(rulesPath)
  });

  let output = '';
  firebase.stdout.on('data', (data) => {
    output += data;
    process.stdout.write(data);
  });
  firebase.stderr.on('data', (data) => {
    output += data;
    process.stderr.write(data);
  });

  const timeout = setTimeout(() => {
    firebase.kill();
  }, 30000);

  firebase.on('close', (code) => {
    clearTimeout(timeout);
    if (code === 0) {
      console.log('\n✓ Rules deployed successfully via Firebase CLI!');
      resolve();
    } else {
      reject(new Error('Both gcloud and firebase deploy failed'));
    }
  });

  firebase.on('error', () => {
    reject(new Error('Firebase CLI not available'));
  });
}

async function seedBrisbaneFood() {
  console.log('\n✓ Proceeding to seed 27 Brisbane food businesses...\n');

  return new Promise((resolve, reject) => {
    const seed = spawn('node', [
      path.join(__dirname, 'seed_brisbane_cbd_rest.js')
    ], { stdio: 'inherit' });

    seed.on('close', (code) => {
      if (code === 0) {
        console.log('\n✓ All done! 27 Brisbane food businesses have been seeded to Firestore.');
        resolve();
      } else {
        reject(new Error('Seeding process failed'));
      }
    });

    seed.on('error', reject);
  });
}

// Run it
main().catch(err => {
  console.error('\n✗ Fatal error:', err.message);
  process.exit(1);
});
