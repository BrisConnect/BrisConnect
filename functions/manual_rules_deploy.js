#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const https = require('https');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const rulesPath = path.join(__dirname, '../firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

function displayRulesContent() {
  console.log('\n');
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║  FIRESTORE RULES CONTENT TO COPY AND PASTE                   ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log('\n');
  console.log(rules);
  console.log('\n');
  console.log('╔════════════════════════════════════════════════════════════════╗');
}

function seedFoodBusinesses() {
  console.log('\n✓ Rules deployed successfully!');
  console.log('\nProceeding to seed 27 Brisbane CBD food businesses...\n');
  
  const apiKey = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';
  const projectId = 'brisconnect-68b78';
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  
  const businesses = [
    {
      name: "Aria Brisbane",
      description: "Fine dining Australian cuisine with stunning city views",
      address: "Level 2, 1 South Bank Parkway, Brisbane",
      phone: "+61 7 3225 6300",
      website: "https://www.ariabristol.com",
      cuisineTypes: ["Fine Dining", "Australian"],
      imageUrl: "https://images.unsplash.com/photo-1504674900152-b8f9ad7ce616?w=400&h=300&fit=crop",
      coordinates: { latitude: -27.4852, longitude: 153.0169 },
      rating: 4.8,
      reviewCount: 342,
      priceRange: "$$$",
      createdAt: new Date().toISOString()
    },
    // ... (include all 27 businesses from your seed data)
  ];
  
  console.log(`Starting to seed ${businesses.length} food businesses...`);
  
  let completed = 0;
  let failed = 0;
  
  businesses.forEach((business, index) => {
    const docId = business.name.toLowerCase().replace(/\s+/g, '_');
    const documentPath = `${baseUrl}/food_businesses/${docId}`;
    
    const payload = {
      fields: {
        name: { stringValue: business.name },
        description: { stringValue: business.description },
        address: { stringValue: business.address },
        phone: { stringValue: business.phone },
        website: { stringValue: business.website },
        cuisineTypes: { arrayValue: { values: business.cuisineTypes.map(c => ({ stringValue: c })) } },
        imageUrl: { stringValue: business.imageUrl },
        coordinates: {
          mapValue: {
            fields: {
              latitude: { doubleValue: business.coordinates.latitude },
              longitude: { doubleValue: business.coordinates.longitude }
            }
          }
        },
        rating: { doubleValue: business.rating },
        reviewCount: { integerValue: business.reviewCount },
        priceRange: { stringValue: business.priceRange },
        createdAt: { timestampValue: business.createdAt }
      }
    };
    
    const options = {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    setTimeout(() => {
      https.request(`${documentPath}?key=${apiKey}`, options, (res) => {
        if (res.statusCode === 200) {
          completed++;
          console.log(`✓ [${index + 1}/${businesses.length}] ${business.name} - Seeded`);
        } else {
          failed++;
          console.log(`✗ [${index + 1}/${businesses.length}] ${business.name} - Failed (${res.statusCode})`);
        }
        
        if (completed + failed === businesses.length) {
          console.log(`\n✓ Seeding complete: ${completed} successful, ${failed} failed`);
          process.exit(0);
        }
      }).on('error', (err) => {
        failed++;
        console.log(`✗ [${index + 1}/${businesses.length}] ${business.name} - Error: ${err.message}`);
        if (completed + failed === businesses.length) {
          console.log(`\n✓ Seeding complete: ${completed} successful, ${failed} failed`);
          process.exit(1);
        }
      }).end(JSON.stringify(payload));
    }, index * 500); // Stagger requests by 500ms to avoid rate limiting
  });
}

function askToDeploy() {
  displayRulesContent();
  
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║  MANUAL DEPLOYMENT INSTRUCTIONS                               ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log('\n1. Open Firebase Console Rules page:');
  console.log('   https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules\n');
  console.log('2. Click the "Edit Rules" button\n');
  console.log('3. Select all existing content (Cmd+A or Ctrl+A)\n');
  console.log('4. Delete the existing content\n');
  console.log('5. Paste the rules content shown above\n');
  console.log('6. Click the "Publish" button\n');
  console.log('7. Wait for the success message\n');
  
  rl.question('Have you successfully deployed the rules? (yes/no): ', (answer) => {
    if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
      rl.close();
      seedFoodBusinesses();
    } else if (answer.toLowerCase() === 'no' || answer.toLowerCase() === 'n') {
      console.log('\nPlease follow the instructions above and try again.');
      rl.close();
      process.exit(1);
    } else {
      console.log('\nPlease enter "yes" or "no"');
      askToDeploy();
    }
  });
}

// Start
console.clear();
console.log('╔════════════════════════════════════════════════════════════════╗');
console.log('║  BRISCONNECT - FIRESTORE RULES & SEED DATA DEPLOYMENT          ║');
console.log('╚════════════════════════════════════════════════════════════════╝');
askToDeploy();
