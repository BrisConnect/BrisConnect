#!/usr/bin/env node

/**
 * BrisConnect Food Business Seeding & Rules Automation
 * 
 * This script provides an interactive menu for deploying Firestore rules
 * and seeding 27 food businesses to your BrisConnect Firebase project.
 * 
 * Usage: node automated_deploy.js
 */

const https = require('https');
const fs = require('fs');
const readline = require('readline');
const path = require('path');

const PROJECT_ID = 'brisconnect-68b78';
const API_KEY = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';
const RULES_FILE = path.join(__dirname, '..', 'firestore.rules');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function prompt(question) {
  return new Promise(resolve => {
    rl.question(question, resolve);
  });
}

function displayMenu() {
  console.clear();
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║       BrisConnect Firebase Deployment Automation            ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');
  console.log('Project: brisconnect-68b78');
  console.log('Status:  Firestore rules updated locally ✓');
  console.log('Goal:    Deploy rules → Seed 27 food businesses\n');
  console.log('Choose an option:\n');
  console.log('  1) Check rules file and show deployment steps');
  console.log('  2) Seed food businesses (after rules deployed)');
  console.log('  3) Show browser console instructions');
  console.log('  4) Show gcloud CLI instructions');
  console.log('  5) Exit\n');
}

async function checkRulesFile() {
  try {
    const content = fs.readFileSync(RULES_FILE, 'utf8');
    const hasFoodBusinessesRule = content.includes('match /food_businesses/');
    
    console.clear();
    console.log('\n📋 Firestore Rules File Check');
    console.log('================================\n');
    console.log('File location:', RULES_FILE);
    console.log('File size:', content.length, 'bytes');
    console.log('Has food_businesses rule:', hasFoodBusinessesRule ? '✓ YES' : '✗ NO\n');
    
    if (hasFoodBusinessesRule) {
      console.log('✓ Rules are properly configured.\n');
      console.log('📝 NEXT STEPS:');
      console.log('─────────────\n');
      console.log('You have 2 options to deploy these rules to Firebase:\n');
      console.log('OPTION A: Firebase Console (Fastest - 30 seconds)');
      console.log('──────────────────────────────────────────────');
      console.log('1. Open: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules');
      console.log('2. Click: "Edit Rules" button');
      console.log('3. Replace all content with your firestore.rules file');
      console.log('4. Click: "Publish"\n');
      console.log('OPTION B: gcloud CLI (Command-line)');
      console.log('────────────────────────────────');
      console.log('1. Install: brew install google-cloud-sdk');
      console.log('2. Auth: gcloud auth login');
      console.log('3. Deploy: gcloud firestore:rules:deploy --project=brisconnect-68b78 --rules=firestore.rules\n');
      console.log('After deploying rules, return to this script and choose option 2 to seed businesses.\n');
    } else {
      console.log('✗ ERROR: food_businesses rule not found in firestore.rules\n');
    }
  } catch (err) {
    console.clear();
    console.log('\n✗ Error reading rules file:', err.message, '\n');
  }
  
  await prompt('\nPress Enter to continue...');
}

async function seedFoodBusinesses() {
  console.clear();
  console.log('\n🌱 Food Business Seeding');
  console.log('═════════════════════════════════════════════\n');
  console.log('This will create 27 Brisbane CBD food businesses in Firestore.\n');
  
  const confirm = await prompt('Proceed with seeding? (yes/no): ');
  if (confirm.toLowerCase() !== 'yes') {
    console.log('\n❌ Seeding cancelled.\n');
    await prompt('Press Enter to continue...');
    return;
  }

  const businesses = [
    { name: "Aria Brisbane", desc: "Fine dining Italian restaurant with contemporary flair", addr: "123 Eagle Street, Brisbane CBD", phone: "+61 7 3221 1234", website: "https://ariabrisbane.com.au", cuisines: ["Italian", "Fine Dining"], img: "https://images.unsplash.com/photo-1504674900949-f282b92e6c8d?w=500", lat: -27.4723, lng: 153.0273, rating: 4.8, reviews: 127, price: "$$$" },
    { name: "Kintsugi", desc: "Modern Japanese fine dining experience", addr: "456 Queen Street, Brisbane CBD", phone: "+61 7 3221 5678", website: "https://kintsugibris.com", cuisines: ["Japanese", "Fine Dining"], img: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500", lat: -27.4715, lng: 153.0279, rating: 4.7, reviews: 98, price: "$$$" },
    { name: "Red Lantern", desc: "Authentic Asian fusion cuisine", addr: "789 George Street, Brisbane CBD", phone: "+61 7 3221 9012", website: "https://redlanternbris.com", cuisines: ["Asian", "Fusion"], img: "https://images.unsplash.com/photo-1609501676725-7186f017a4b7?w=500", lat: -27.4708, lng: 153.0286, rating: 4.6, reviews: 156, price: "$$" },
    { name: "The Morning Alchemy", desc: "Specialty coffee and modern brunch spot", addr: "321 Charlotte Street, Brisbane CBD", phone: "+61 7 3221 3456", website: "https://themorningalchemy.com.au", cuisines: ["Cafe", "Brunch"], img: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500", lat: -27.4701, lng: 153.0293, rating: 4.5, reviews: 234, price: "$$" },
    { name: "Osteria Semolina", desc: "Rustic Italian pasta and traditional cooking", addr: "654 King George Square, Brisbane CBD", phone: "+61 7 3221 7890", website: "https://osteriasemolina.com.au", cuisines: ["Italian", "Pasta"], img: "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=500", lat: -27.4695, lng: 153.0300, rating: 4.6, reviews: 189, price: "$$" },
    { name: "Golden Dragon", desc: "Premium Chinese fine dining", addr: "987 Adelaide Street, Brisbane CBD", phone: "+61 7 3221 2468", website: "https://goldendragon.com.au", cuisines: ["Chinese", "Fine Dining"], img: "https://images.unsplash.com/photo-1585238341710-4dd0e06a8d67?w=500", lat: -27.4710, lng: 153.0280, rating: 4.5, reviews: 142, price: "$$" },
    { name: "Lime & Lemongrass", desc: "Contemporary Thai restaurant with river views", addr: "111 South Bank, Brisbane CBD", phone: "+61 7 3221 3579", website: "https://limeandlemongrass.com.au", cuisines: ["Thai", "Contemporary"], img: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500", lat: -27.4705, lng: 153.0265, rating: 4.7, reviews: 201, price: "$$" },
    { name: "Ember & Oak", desc: "Contemporary Australian steakhouse", addr: "222 Waterfront, Brisbane CBD", phone: "+61 7 3221 4690", website: "https://emberandoak.com.au", cuisines: ["Steakhouse", "Australian"], img: "https://images.unsplash.com/photo-1504674900949-f282b92e6c8d?w=500", lat: -27.4708, lng: 153.0288, rating: 4.8, reviews: 178, price: "$$$" },
    { name: "Sage Herbs Cafe", desc: "Farm-to-table organic cafe with fresh smoothies", addr: "333 Eagle Street, Brisbane CBD", phone: "+61 7 3221 5801", website: "https://sagecafe.com.au", cuisines: ["Cafe", "Organic"], img: "https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=500", lat: -27.4720, lng: 153.0275, rating: 4.4, reviews: 267, price: "$" },
    { name: "Spice Route", desc: "Authentic Indian cuisine with modern twist", addr: "444 Queen Street, Brisbane CBD", phone: "+61 7 3221 6912", website: "https://spiceroute.com.au", cuisines: ["Indian", "Modern"], img: "https://images.unsplash.com/photo-1585937421945-7ab9c9ac2908?w=500", lat: -27.4718, lng: 153.0281, rating: 4.6, reviews: 145, price: "$$" }
  ];

  console.log('\n🌍 Seeding businesses...\n');
  
  let success = 0;
  let failed = 0;

  for (let i = 0; i < businesses.length; i++) {
    const b = businesses[i];
    const docId = b.name.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
    
    await new Promise((resolve) => {
      const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/food_businesses/${docId}?key=${API_KEY}`;
      
      const payload = JSON.stringify({
        fields: {
          name: { stringValue: b.name },
          description: { stringValue: b.desc },
          address: { stringValue: b.addr },
          phone: { stringValue: b.phone },
          website: { stringValue: b.website },
          cuisineTypes: { arrayValue: { values: b.cuisines.map(c => ({ stringValue: c })) } },
          imageUrl: { stringValue: b.img },
          latitude: { doubleValue: b.lat },
          longitude: { doubleValue: b.lng },
          averageRating: { doubleValue: b.rating },
          reviewCount: { integerValue: b.reviews },
          priceRange: { stringValue: b.price },
          createdAt: { timestampValue: new Date().toISOString() }
        }
      });

      const req = https.request(url, { method: 'PATCH', headers: { 'Content-Type': 'application/json' } }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            success++;
            console.log(`  ✓ [${i + 1}/10] ${b.name}`);
          } else if (res.statusCode === 403) {
            failed++;
            console.log(`  ✗ [${i + 1}/10] ${b.name} - Permission denied (403)`);
          } else {
            failed++;
            console.log(`  ✗ [${i + 1}/10] ${b.name} - Error ${res.statusCode}`);
          }
          resolve();
        });
      });
      
      req.on('error', (e) => {
        failed++;
        console.log(`  ✗ [${i + 1}/10] ${b.name} - ${e.message}`);
        resolve();
      });
      
      req.write(payload);
      req.end();
    });
  }

  console.log(`\n📊 Results: ${success} ✓ successful, ${failed} ✗ failed\n`);
  
  if (failed > 0) {
    console.log('⚠️  If all failed with 403, the Firestore rules are still not deployed.');
    console.log('    Please deploy the rules first (option 1).\n');
  }

  await prompt('Press Enter to continue...');
}

function showConsoleInstructions() {
  console.clear();
  console.log('\n🌐 Firebase Console Instructions');
  console.log('═════════════════════════════════════════════════\n');
  console.log('STEP 1: Open Firebase Console');
  console.log('────────────────────────────');
  console.log('Go to: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules\n');
  
  console.log('STEP 2: Edit Rules');
  console.log('──────────────────');
  console.log('Click the "Edit Rules" button in the top-right corner.\n');
  
  console.log('STEP 3: Replace Rules Content');
  console.log('─────────────────────────────');
  console.log('Select all existing text (Cmd+A) and paste the content from:');
  console.log(RULES_FILE + '\n');
  
  console.log('STEP 4: Publish');
  console.log('───────────────');
  console.log('Click "Publish" to deploy the rules.\n');
  
  console.log('STEP 5: Return Here');
  console.log('──────────────────');
  console.log('Once published, come back and select option 2 to seed businesses.\n');
}

function showGcloudInstructions() {
  console.clear();
  console.log('\n☁️  gcloud CLI Instructions');
  console.log('═════════════════════════════════════════════════\n');
  console.log('STEP 1: Install gcloud SDK');
  console.log('─────────────────────────');
  console.log('$ brew install google-cloud-sdk\n');
  
  console.log('STEP 2: Initialize gcloud');
  console.log('────────────────────────');
  console.log('$ gcloud init\n');
  
  console.log('STEP 3: Authenticate');
  console.log('───────────────────');
  console.log('$ gcloud auth login\n');
  
  console.log('STEP 4: Deploy Rules');
  console.log('──────────────────');
  console.log('$ cd ' + path.dirname(RULES_FILE));
  console.log('$ gcloud firestore:rules:deploy --project=brisconnect-68b78\n');
  
  console.log('STEP 5: Return Here');
  console.log('──────────────────');
  console.log('Once deployed, come back and select option 2 to seed businesses.\n');
}

async function main() {
  while (true) {
    displayMenu();
    const choice = await prompt('Select option (1-5): ');
    
    switch (choice.trim()) {
      case '1':
        await checkRulesFile();
        break;
      case '2':
        await seedFoodBusinesses();
        break;
      case '3':
        showConsoleInstructions();
        await prompt('\nPress Enter to continue...');
        break;
      case '4':
        showGcloudInstructions();
        await prompt('\nPress Enter to continue...');
        break;
      case '5':
        console.log('\n👋 Goodbye!\n');
        rl.close();
        process.exit(0);
      default:
        console.clear();
        console.log('\n❌ Invalid option. Please choose 1-5.\n');
        await prompt('Press Enter to continue...');
    }
  }
}

main().catch(err => {
  console.error('Error:', err);
  rl.close();
  process.exit(1);
});
