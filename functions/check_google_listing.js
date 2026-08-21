const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkBusiness() {
  // Check a business that should be seeded
  const snapshot = await db.collection('food_businesses')
    .where('businessName', '==', 'Cafe Da Vina')
    .limit(1)
    .get();
  
  if (snapshot.empty) {
    console.log('Business not found in food_businesses collection');
    return;
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  
  console.log('Found business:', doc.id);
  console.log('businessName:', data.businessName);
  console.log('isGoogleListing:', data.isGoogleListing);
  console.log('sourceProvider:', data.sourceProvider);
}

checkBusiness()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
