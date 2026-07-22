const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Before running: 
// 1. Download your serviceAccountKey.json from Firebase Console
// 2. Place it in the functions directory
// 3. Update the path below

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteCollection(collectionPath) {
  try {
    console.log(`\n🗑️  Deleting collection: ${collectionPath}`);
    
    const query = db.collection(collectionPath);
    const snapshot = await query.get();
    
    if (snapshot.empty) {
      console.log(`   ✅ Collection already empty or doesn't exist`);
      return;
    }

    let deleteCount = 0;
    const batchSize = 100;
    
    // Delete in batches (Firestore limit)
    for (let i = 0; i < snapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      const end = Math.min(i + batchSize, snapshot.docs.length);
      
      for (let j = i; j < end; j++) {
        batch.delete(snapshot.docs[j].ref);
        deleteCount++;
      }
      
      await batch.commit();
    }

    console.log(`   ✅ Deleted ${deleteCount} documents`);
  } catch (error) {
    console.error(`   ❌ Error:`, error.message);
  }
}

async function cleanupFirestore() {
  console.log('🧹 Starting Firestore cleanup - Removing non-food-business collections\n');
  console.log('=====================================');

  // Collections NOT relevant to food businesses - TO DELETE
  const collectionsToDelete = [
    'attractions',
    'attraction_details',
    'brisbane_voices',
  ];

  console.log('Collections to be deleted:');
  collectionsToDelete.forEach(c => console.log(`  - ${c}`));

  console.log('\n=====================================');
  console.log('Processing deletions...\n');

  for (const collection of collectionsToDelete) {
    await deleteCollection(collection);
  }

  console.log('\n=====================================');
  console.log('✅ Cleanup completed!\n');
  console.log('📊 Remaining collections (food business relevant):');
  console.log('  ✓ businesses - restaurants, cafes, food places');
  console.log('  ✓ events - local events');
  console.log('  ✓ local_users, Users, admins - user authentication');
  console.log('  ✓ config - system configuration');
  console.log('  ✓ counters - ID counters');
  console.log('  ✓ mail, sms_queue - notifications');
  console.log('  ✓ event_reports - event reporting');
  console.log('  ✓ app_feedback - general feedback');
  console.log('=====================================\n');

  process.exit(0);
}

cleanupFirestore().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
