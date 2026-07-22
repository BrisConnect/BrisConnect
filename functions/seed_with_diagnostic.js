#!/usr/bin/env node

const https = require('https');

// Instead of trying to update rules, let's seed using the REST API
// with proper formatting for Firestore
const PROJECT_ID = 'brisconnect-68b78';
const API_KEY = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';

const businesses = [
  {
    name: "Aria Brisbane",
    description: "Fine dining Italian restaurant with contemporary flair",
    address: "123 Eagle Street, Brisbane CBD",
    phone: "+61 7 3221 1234",
    website: "https://ariabrisbane.com.au",
    cuisineTypes: ["Italian", "Fine Dining"],
    imageUrl: "https://images.unsplash.com/photo-1504674900949-f282b92e6c8d?w=500",
    latitude: -27.4723,
    longitude: 153.0273,
    averageRating: 4.8,
    reviewCount: 127,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Kintsugi",
    description: "Modern Japanese fine dining experience",
    address: "456 Queen Street, Brisbane CBD",
    phone: "+61 7 3221 5678",
    website: "https://kintsugibris.com",
    cuisineTypes: ["Japanese", "Fine Dining"],
    imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500",
    latitude: -27.4715,
    longitude: 153.0279,
    averageRating: 4.7,
    reviewCount: 98,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Red Lantern",
    description: "Authentic Asian fusion cuisine",
    address: "789 George Street, Brisbane CBD",
    phone: "+61 7 3221 9012",
    website: "https://redlanternbris.com",
    cuisineTypes: ["Asian", "Fusion"],
    imageUrl: "https://images.unsplash.com/photo-1609501676725-7186f017a4b7?w=500",
    latitude: -27.4708,
    longitude: 153.0286,
    averageRating: 4.6,
    reviewCount: 156,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "The Morning Alchemy",
    description: "Specialty coffee and modern brunch spot",
    address: "321 Charlotte Street, Brisbane CBD",
    phone: "+61 7 3221 3456",
    website: "https://themorningalchemy.com.au",
    cuisineTypes: ["Cafe", "Brunch"],
    imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500",
    latitude: -27.4701,
    longitude: 153.0293,
    averageRating: 4.5,
    reviewCount: 234,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Osteria Semolina",
    description: "Rustic Italian pasta and traditional cooking",
    address: "654 King George Square, Brisbane CBD",
    phone: "+61 7 3221 7890",
    website: "https://osteriasemolina.com.au",
    cuisineTypes: ["Italian", "Pasta"],
    imageUrl: "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=500",
    latitude: -27.4695,
    longitude: 153.0300,
    averageRating: 4.6,
    reviewCount: 189,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  }
];

console.log('📋 Attempting to seed food businesses using REST API...\n');

let successCount = 0;
let failCount = 0;
let completed = 0;

businesses.forEach((business, index) => {
  setTimeout(() => {
    const docId = business.name.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/food_businesses/${docId}?key=${API_KEY}`;
    
    const fields = {
      name: { stringValue: business.name },
      description: { stringValue: business.description },
      address: { stringValue: business.address },
      phone: { stringValue: business.phone },
      website: { stringValue: business.website },
      cuisineTypes: { arrayValue: { values: business.cuisineTypes.map(c => ({ stringValue: c })) } },
      imageUrl: { stringValue: business.imageUrl },
      latitude: { doubleValue: business.latitude },
      longitude: { doubleValue: business.longitude },
      averageRating: { doubleValue: business.averageRating },
      reviewCount: { integerValue: business.reviewCount },
      priceRange: { stringValue: business.priceRange },
      createdAt: { timestampValue: business.createdAt }
    };

    const payload = JSON.stringify({ fields });
    
    const options = {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          successCount++;
          console.log(`✓ [${index + 1}/${businesses.length}] ${business.name} - Success`);
        } else if (res.statusCode === 403) {
          failCount++;
          console.log(`✗ [${index + 1}/${businesses.length}] ${business.name} - Permission denied (403)`);
          if (index === 0) {
            console.log('\n⚠️  Firestore rules are blocking writes. Need to update rules at:');
            console.log('   https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules');
            console.log('\n📝 Replace content with firestore.rules from your project directory.');
          }
        } else {
          failCount++;
          console.log(`✗ [${index + 1}/${businesses.length}] ${business.name} - Error ${res.statusCode}`);
        }
        
        completed++;
        if (completed === businesses.length) {
          console.log(`\n📊 Results: ${successCount} ✓ successful, ${failCount} ✗ failed\n`);
        }
      });
    });

    req.on('error', (e) => {
      failCount++;
      console.log(`✗ [${index + 1}/${businesses.length}] ${business.name} - ${e.message}`);
      completed++;
    });

    req.write(payload);
    req.end();
  }, index * 100); // Stagger requests
});
