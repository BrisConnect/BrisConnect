#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');
const { spawn } = require('child_process');

const rulesPath = path.join(__dirname, '../firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

const projectId = 'brisconnect-68b78';
const apiKey = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';

console.log('\n╔════════════════════════════════════════════════════════════════╗');
console.log('║  AUTOMATED FIRESTORE RULES DEPLOYMENT                         ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

// Try multiple deployment methods
async function deployRules() {
  const methods = [
    methodGcloudDeploy,
    methodFirebaseDeployRetry,
    methodBrowserAutomation,
    methodManualFallback
  ];

  for (const method of methods) {
    try {
      console.log(`\n📋 Attempting method: ${method.name}...`);
      const result = await method();
      if (result) {
        console.log('\n✓ Rules deployed successfully!');
        seedData();
        return;
      }
    } catch (err) {
      console.log(`✗ Method failed: ${err.message}`);
      continue;
    }
  }

  console.error('\n✗ All deployment methods failed. Please use manual deployment.');
  process.exit(1);
}

async function methodGcloudDeploy() {
  return new Promise((resolve, reject) => {
    const process = spawn('gcloud', [
      'firestore:rules:deploy',
      rulesPath,
      `--project=${projectId}`
    ], { stdio: 'pipe' });

    let output = '';
    process.stdout.on('data', (data) => {
      output += data;
    });
    process.stderr.on('data', (data) => {
      output += data;
    });
    process.on('close', (code) => {
      if (code === 0) {
        resolve(true);
      } else {
        reject(new Error('gcloud deploy failed'));
      }
    });

    setTimeout(() => {
      process.kill();
      reject(new Error('Timeout'));
    }, 10000);
  });
}

async function methodFirebaseDeployRetry() {
  return new Promise((resolve, reject) => {
    const process = spawn('firebase', [
      'deploy',
      '--only', 'firestore:rules',
      '--project', projectId
    ], { stdio: 'pipe', cwd: path.dirname(rulesPath) });

    let output = '';
    process.stdout.on('data', (data) => {
      output += data;
    });
    process.stderr.on('data', (data) => {
      output += data;
    });
    process.on('close', (code) => {
      if (code === 0) {
        resolve(true);
      } else {
        reject(new Error('firebase deploy failed'));
      }
    });

    setTimeout(() => {
      process.kill();
      reject(new Error('Timeout'));
    }, 15000);
  });
}

async function methodBrowserAutomation() {
  // Try to use puppeteer for headless browser automation
  try {
    const puppeteer = require('puppeteer');
    console.log('  Using Puppeteer for browser automation...');
    
    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();
    
    // Navigate to Firebase Console Rules page
    await page.goto('https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    // Wait for authentication - if not authenticated, this will fail
    try {
      await page.waitForFunction(() => {
        const editButton = document.querySelector('button[aria-label*="Edit"]');
        return editButton !== null;
      }, { timeout: 5000 });
    } catch (e) {
      throw new Error('Not authenticated - need manual login');
    }

    // Click Edit Rules button
    await page.click('button[aria-label*="Edit"]');
    await page.waitForTimeout(1000);

    // Find the code editor (usually Monaco or similar)
    const editorSelector = '[role="textbox"]';
    await page.waitForSelector(editorSelector, { timeout: 5000 });

    // Clear existing content and paste new rules
    await page.focus(editorSelector);
    await page.keyboard.press('KeyA', { control: true });
    await page.keyboard.press('Backspace');
    await page.type(editorSelector, rules, { delay: 5 });

    // Click Publish button
    const publishButton = await page.$('button[aria-label*="Publish"], button:contains("Publish")');
    if (publishButton) {
      await publishButton.click();
      await page.waitForTimeout(2000);
    }

    await browser.close();
    return true;
  } catch (err) {
    throw new Error(`Browser automation failed: ${err.message}`);
  }
}

async function methodManualFallback() {
  console.log('\n⚠️  Entering manual deployment mode...');
  console.log('\nTo deploy rules manually:');
  console.log('1. Open: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules');
  console.log('2. Click "Edit Rules"');
  console.log('3. Select all (Cmd+A) and delete');
  console.log('4. Paste this content:\n');
  console.log('═'.repeat(70));
  console.log(rules);
  console.log('═'.repeat(70));
  console.log('\n5. Click "Publish"');
  console.log('6. Once deployed, run: npm run seed:food');
  
  return false;
}

async function seedData() {
  console.log('\n⏳ Waiting 3 seconds before seeding...');
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  console.log('\n📦 Starting seed data deployment...\n');
  
  const seedScript = require('./seed_brisbane_cbd_rest.js');
}

deployRules().catch(console.error);
