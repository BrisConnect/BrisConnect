#!/usr/bin/env node

const https = require('https');
const fs = require('fs');

const PROJECT_ID = 'brisconnect-68b78';
const API_KEY = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';

// Read rules file from parent directory
const rulesPath = '/Users/ibrahim_ahhoa/Documents/BrisConnect/firestore.rules';
let rulesContent;
try {
  rulesContent = fs.readFileSync(rulesPath, 'utf8');
  console.log('✓ Rules file read successfully');
  console.log(`  Size: ${rulesContent.length} characters`);
} catch (err) {
  console.error('✗ Failed to read rules file:', err.message);
  process.exit(1);
}

// Create request body for Firestore Rules API
const requestBody = {
  rules: rulesContent
};

const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/securityRules?key=${API_KEY}`;

console.log('\n📤 Sending Firestore rules update...');
console.log(`  Endpoint: ${url.split('?')[0]}`);

const options = {
  method: 'PATCH',
  headers: {
    'Content-Type': 'application/json',
    'User-Agent': 'BrisConnect-Seeder/1.0'
  }
};

const req = https.request(url, options, (res) => {
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`\n📊 Response: ${res.statusCode}`);
    
    if (res.statusCode >= 200 && res.statusCode < 300) {
      console.log('✓ Rules updated successfully!');
      const response = JSON.parse(data);
      console.log(`  Created: ${response.createTime}`);
      if (response.updateTime) console.log(`  Updated: ${response.updateTime}`);
    } else if (res.statusCode === 401 || res.statusCode === 403) {
      console.log('✗ Authentication error. API key may not have rules update permission.');
      console.log('  Please update rules manually via Firebase Console:');
      console.log(`  https://console.firebase.google.com/project/${PROJECT_ID}/firestore/rules`);
    } else {
      console.log(`✗ Request failed with status ${res.statusCode}`);
    }
    
    try {
      const response = JSON.parse(data);
      if (response.error) {
        console.log(`  Error: ${response.error.message}`);
      }
    } catch (e) {
      // Not JSON response
    }
    console.log('\n📝 Response body:', data.substring(0, 200));
  });
});

req.on('error', (e) => {
  console.error('✗ Request error:', e.message);
  process.exit(1);
});

// Send request
req.write(JSON.stringify(requestBody));
req.end();

console.log('⏳ Waiting for response...\n');
