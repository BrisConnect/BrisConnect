/**
 * Delete a BrisConnect user account and all associated Firestore data.
 *
 * Usage:
 *   DRY_RUN=true node delete_user_account.js kirpaldhaliwal56@gmail.com
 *   DRY_RUN=false node delete_user_account.js kirpaldhaliwal56@gmail.com
 */

const admin = require('firebase-admin');
const path = require('path');

const DRY_RUN = process.env.DRY_RUN !== 'false';
const EMAIL = process.argv[2];

if (!EMAIL) {
  console.error('Usage: DRY_RUN=false node delete_user_account.js <email>');
  process.exit(1);
}

const normalizedEmail = EMAIL.trim().toLowerCase();

const serviceAccountPath = path.resolve(__dirname, '../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

const auth = admin.auth();
const db = admin.firestore();

async function getAuthUser() {
  try {
    return await auth.getUserByEmail(normalizedEmail);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return null;
    }
    throw error;
  }
}

async function deleteSubcollection(parentRef, subcollectionName) {
  const snapshot = await parentRef.collection(subcollectionName).get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  if (!DRY_RUN) await batch.commit();
  return snapshot.size;
}

async function deleteUserDocument(collectionName, docId) {
  const ref = db.collection(collectionName).doc(docId);
  const doc = await ref.get();
  if (!doc.exists) return { deleted: false, subcollections: {} };

  const subcollections = await ref.listCollections();
  const subStats = {};
  for (const sub of subcollections) {
    const count = await deleteSubcollection(ref, sub.id);
    if (count > 0) subStats[sub.id] = count;
  }

  if (!DRY_RUN) await ref.delete();
  return { deleted: true, subStats };
}

async function deleteQueryDocs(query, collectionName) {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  if (!DRY_RUN) await batch.commit();
  return snapshot.size;
}

async function main() {
  console.log(`\n${DRY_RUN ? '[DRY RUN]' : '[LIVE DELETE]'} Target: ${normalizedEmail}\n`);

  const authUser = await getAuthUser();
  const authUid = authUser?.uid;

  if (authUser) {
    console.log(`Found Firebase Auth user: uid=${authUid}`);
  } else {
    console.log('No Firebase Auth user found for this email.');
  }

  // 1. Auth account
  if (authUser) {
    if (DRY_RUN) {
      console.log('  [DRY RUN] Would delete Firebase Auth account');
    } else {
      await auth.deleteUser(authUid);
      console.log('  Deleted Firebase Auth account');
    }
  }

  // 2. Core profile documents (document id == normalized email)
  const localUserResult = await deleteUserDocument('local_users', normalizedEmail);
  if (localUserResult.deleted) {
    console.log('  Deleted local_users document');
    Object.entries(localUserResult.subStats).forEach(([name, count]) => {
      console.log(`    Deleted ${count} documents from local_users/${normalizedEmail}/${name}`);
    });
  }

  const visitorUserResult = await deleteUserDocument('visitor_users', normalizedEmail);
  if (visitorUserResult.deleted) {
    console.log('  Deleted visitor_users document');
    Object.entries(visitorUserResult.subStats).forEach(([name, count]) => {
      console.log(`    Deleted ${count} documents from visitor_users/${normalizedEmail}/${name}`);
    });
  }

  // 3. Businesses owned by this user
  const businessCollections = ['food_businesses', 'businesses'];
  for (const coll of businessCollections) {
    const query = db.collection(coll).where('ownerEmail', '==', normalizedEmail);
    const count = await deleteQueryDocs(query, coll);
    if (count > 0) console.log(`  Deleted ${count} documents from ${coll} (ownerEmail)`);

    const altQuery = db.collection(coll).where('email', '==', normalizedEmail);
    const altCount = await deleteQueryDocs(altQuery, coll);
    if (altCount > 0) console.log(`  Deleted ${altCount} documents from ${coll} (email)`);
  }

  // 4. Reviews written by this user
  const reviewsQuery = db.collection('reviews').where('reviewerEmail', '==', normalizedEmail);
  const reviewsCount = await deleteQueryDocs(reviewsQuery, 'reviews');
  if (reviewsCount > 0) console.log(`  Deleted ${reviewsCount} top-level reviews (reviewerEmail)`);

  // 5. Events created by this local user
  const eventsQuery = db.collection('events').where('createdByLocalEmail', '==', normalizedEmail);
  const eventsCount = await deleteQueryDocs(eventsQuery, 'events');
  if (eventsCount > 0) console.log(`  Deleted ${eventsCount} events (createdByLocalEmail)`);

  // 6. Event reports / app feedback created by this user
  const reportsQuery = db.collection('event_reports').where('reportedByEmail', '==', normalizedEmail);
  const reportsCount = await deleteQueryDocs(reportsQuery, 'event_reports');
  if (reportsCount > 0) console.log(`  Deleted ${reportsCount} event_reports`);

  const feedbackQuery = db.collection('app_feedback').where('userEmail', '==', normalizedEmail);
  const feedbackCount = await deleteQueryDocs(feedbackQuery, 'app_feedback');
  if (feedbackCount > 0) console.log(`  Deleted ${feedbackCount} app_feedback entries`);

  // 7. Social shares tracked for this user
  const sharesQuery = db.collection('social_shares').where('sharedByEmail', '==', normalizedEmail);
  const sharesCount = await deleteQueryDocs(sharesQuery, 'social_shares');
  if (sharesCount > 0) console.log(`  Deleted ${sharesCount} social_shares`);

  console.log(`\n${DRY_RUN ? 'Dry run complete.' : 'Deletion complete.'}`);
  if (DRY_RUN) {
    console.log('Run with DRY_RUN=false to actually delete the data.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\nError:', error.message);
    process.exit(1);
  });
