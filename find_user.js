/**
 * Find a user by name in Firestore
 * Usage: node find_user.js "Kirpal Singh"
 */

const admin = require('firebase-admin');
const path = require('path');

const searchName = (process.argv[2] || '').toLowerCase();

if (!searchName) {
  console.error('Usage: node find_user.js <name>');
  process.exit(1);
}

const serviceAccountPath = path.resolve(__dirname, 'service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const db = admin.firestore();

async function findUser() {
  console.log(`Searching for user with name containing: "${searchName}"\n`);

  const collections = ['visitor_users', 'local_users'];
  
  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const docName = (data.name || data.businessName || '').toLowerCase();
      
      if (docName.includes(searchName)) {
        console.log(`Found in ${collectionName}:`);
        console.log(`  Email: ${doc.id}`);
        console.log(`  Name: ${data.name || data.businessName}`);
        console.log(`  Phone: ${data.phone || data.phoneNumber || 'N/A'}`);
        console.log(`  Active: ${data.active !== false}`);
        console.log(`  Created: ${data.createdAt?.toDate?.() || 'N/A'}`);
        console.log('');
      }
    });
  }
}

findUser().then(() => {
  process.exit(0);
}).catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
