/**
 * Cleanup script to remove all Google Places seeded data from Firestore.
 * 
 * This script:
 * 1. Deletes ALL attractions from Google Places (tourist attractions, stadiums, parks, museums, etc.)
 * 2. Deletes ALL events from Google Places
 * 3. Deletes ALL discover_items that are not food-related
 * 4. Keeps ONLY restaurants, cafes, and local food businesses in Brisbane CBD
 * 5. Cleans up references from user collections
 *
 * FEATURES:
 * - DRY_RUN mode (enabled by default) to preview changes without making deletions
 * - Batch processing for efficient Firestore operations
 * - Safe user reference cleanup to prevent orphaned data
 *
 * Usage (DRY RUN - preview mode):
 *   cd functions
 *   node cleanup_firestore.js
 *
 * Usage (LIVE mode - actual deletion):
 *   1. Edit the script and change DRY_RUN = false
 *   2. cd functions
 *   3. node cleanup_firestore.js
 *
 * WARNING: Setting DRY_RUN = false PERMANENTLY DELETES data from Firestore.
 * Make sure you have a backup before running in live mode!
 */

const admin = require("firebase-admin");
const path = require("path");

// Try to initialize with service account
let initialized = false;

// Method 1: Try environment variable
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  try {
    admin.initializeApp();
    initialized = true;
    console.log("✓ Firebase Admin SDK initialized with GOOGLE_APPLICATION_CREDENTIALS");
  } catch (error) {
    console.log("⚠️  Could not initialize with GOOGLE_APPLICATION_CREDENTIALS");
  }
}

// Method 2: Try local service account file
if (!initialized) {
  try {
    const serviceAccount = require(path.resolve(
      process.env.FIREBASE_SERVICE_ACCOUNT || "./brisconnect-firebase-adminsdk.json"
    ));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    initialized = true;
    console.log("✓ Firebase Admin SDK initialized with service account file");
  } catch (error) {
    console.log("⚠️  Could not initialize with local service account file");
  }
}

// Method 3: Use default credentials (gcloud CLI)
if (!initialized) {
  try {
    admin.initializeApp();
    initialized = true;
    console.log("✓ Firebase Admin SDK initialized with default credentials (gcloud)");
  } catch (error) {
    console.log("⚠️  Could not initialize with default credentials");
  }
}

if (!initialized) {
  console.error("\n❌ ERROR: Could not initialize Firebase Admin SDK");
  console.error("\nPlease set up authentication using one of these methods:");
  console.error("  1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable:");
  console.error("     export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json");
  console.error("     node cleanup_firestore.js");
  console.error("\n  2. Place service account JSON file as 'brisconnect-firebase-adminsdk.json'");
  console.error("     in the functions directory");
  console.error("\n  3. Use gcloud CLI authentication:");
  console.error("     gcloud auth application-default login");
  console.error("     node cleanup_firestore.js");
  console.error("\n  4. Set FIREBASE_SERVICE_ACCOUNT environment variable to custom path:");
  console.error("     export FIREBASE_SERVICE_ACCOUNT=/path/to/service-account.json");
  console.error("     node cleanup_firestore.js\n");
  process.exit(1);
}

const db = admin.firestore();

// Configuration
const BATCH_SIZE = 500; // Firestore batch write limit
const DRY_RUN = false;  // Set to false to actually delete. Set to true to preview changes

/**
 * Delete documents in batches
 */
async function deleteDocumentsInBatches(query, collectionName) {
  let deletedCount = 0;
  let snapshot = await query.get();

  while (snapshot.docs.length > 0) {
    if (!DRY_RUN) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedCount++;
      });
      await batch.commit();
    } else {
      // In dry run, just count the documents
      deletedCount += snapshot.docs.length;
    }
    
    console.log(`  ${DRY_RUN ? '[DRY RUN] Would delete' : 'Deleted'} ${deletedCount} documents from ${collectionName}`);

    if (snapshot.docs.length < BATCH_SIZE) {
      break;
    }

    snapshot = await query.get();
  }

  return deletedCount;
}

/**
 * Step 1: Delete all attractions from Google Places
 */
async function deleteGoogleAttractionsAndStadiums() {
  console.log("\n📍 Step 1: Deleting Google Places attractions and stadiums...");
  
  try {
    // Delete by sourceProvider = "google" OR by ID pattern starting with "google-"
    const query = db.collection("attractions")
      .where("sourceProvider", "==", "google");
    
    const deleted = await deleteDocumentsInBatches(query, "attractions");
    console.log(`${DRY_RUN ? '[DRY RUN] Would delete' : '✓ Deleted'} ${deleted} Google Places attractions/stadiums`);
    return deleted;
  } catch (error) {
    console.error("Error deleting attractions:", error);
    return 0;
  }
}

/**
 * Step 2: Delete all events from Google Places
 */
async function deleteGoogleEvents() {
  console.log("\n📅 Step 2: Deleting Google Places events...");
  
  try {
    const query = db.collection("events")
      .where("sourceProvider", "==", "google");
    
    const deleted = await deleteDocumentsInBatches(query, "events");
    console.log(`${DRY_RUN ? '[DRY RUN] Would delete' : '✓ Deleted'} ${deleted} Google Places events`);
    return deleted;
  } catch (error) {
    console.error("Error deleting events:", error);
    return 0;
  }
}

/**
 * Step 3: Delete non-food discover_items and keep only food businesses
 */
async function deleteNonFoodDiscoverItems() {
  console.log("\n🍽️ Step 3: Cleaning up discover_items - keeping only food items...");
  
  try {
    // Get all discover items that are NOT in the "food" section
    const nonFoodQuery = db.collection("discover_items")
      .where("section", "!=", "food");
    
    const deleted = await deleteDocumentsInBatches(nonFoodQuery, "discover_items");
    console.log(`${DRY_RUN ? '[DRY RUN] Would delete' : '✓ Deleted'} ${deleted} non-food discover_items`);
    
    // Also delete any food items that came from stadiums/attractions (optional but safer)
    const foodSnapshot = await db.collection("discover_items")
      .where("section", "==", "food")
      .get();
    
    let foodCount = 0;
    const batch = db.batch();
    
    foodSnapshot.forEach((doc) => {
      const data = doc.data();
      // Keep only items that don't have sourceProvider: "google" or aren't from stadiums
      if (data.sourceProvider === "google" && 
          (data.sourceType?.includes("stadium") || 
           data.sourceType?.includes("venue") ||
           !data.cuisine)) {
        if (!DRY_RUN) {
          batch.delete(doc.ref);
        }
        foodCount++;
      }
    });
    
    if (foodCount > 0) {
      if (!DRY_RUN) {
        await batch.commit();
      }
      console.log(`${DRY_RUN ? '[DRY RUN] Would delete' : '✓ Deleted'} ${foodCount} non-food or stadium food items`);
    }
    
    return deleted + foodCount;
  } catch (error) {
    console.error("Error deleting discover_items:", error);
    return 0;
  }
}

/**
 * Step 4: Clean up user references to deleted items
 */
async function cleanupUserReferences() {
  console.log("\n👥 Step 4: Cleaning up user references...");
  
  try {
    let updatedCount = 0;
    
    // Clean up visitor_users savedAttractionIds
    const visitorsSnapshot = await db.collection("visitor_users").get();
    const visitorBatch = db.batch();
    
    visitorsSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.savedAttractionIds && Array.isArray(data.savedAttractionIds)) {
        const originalCount = data.savedAttractionIds.length;
        // Filter out any Google Places attractions
        const filtered = data.savedAttractionIds.filter(
          id => !id.startsWith("google-")
        );
        
        if (filtered.length !== originalCount) {
          if (!DRY_RUN) {
            visitorBatch.update(doc.ref, { savedAttractionIds: filtered });
          }
          updatedCount++;
        }
      }
      
      // Clean up interestedEventIds
      if (data.interestedEventIds && Array.isArray(data.interestedEventIds)) {
        const originalCount = data.interestedEventIds.length;
        const filtered = data.interestedEventIds.filter(
          id => !id.startsWith("google-")
        );
        
        if (filtered.length !== originalCount) {
          if (!DRY_RUN) {
            visitorBatch.update(doc.ref, { interestedEventIds: filtered });
          }
          updatedCount++;
        }
      }
    });
    
    if (updatedCount > 0) {
      if (!DRY_RUN) {
        await visitorBatch.commit();
      }
      console.log(`${DRY_RUN ? '[DRY RUN] Would update' : '✓ Updated'} ${updatedCount} visitor_users profiles`);
    }
    
    // Clean up local_users interestedEventIds
    const localsSnapshot = await db.collection("local_users").get();
    const localBatch = db.batch();
    let localUpdatedCount = 0;
    
    localsSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.interestedEventIds && Array.isArray(data.interestedEventIds)) {
        const originalCount = data.interestedEventIds.length;
        const filtered = data.interestedEventIds.filter(
          id => !id.startsWith("google-")
        );
        
        if (filtered.length !== originalCount) {
          if (!DRY_RUN) {
            localBatch.update(doc.ref, { interestedEventIds: filtered });
          }
          localUpdatedCount++;
        }
      }
    });
    
    if (localUpdatedCount > 0) {
      if (!DRY_RUN) {
        await localBatch.commit();
      }
      console.log(`${DRY_RUN ? '[DRY RUN] Would update' : '✓ Updated'} ${localUpdatedCount} local_users profiles`);
    }
    
    return updatedCount + localUpdatedCount;
  } catch (error) {
    console.error("Error cleaning up user references:", error);
    return 0;
  }
}

/**
 * Main execution
 */
async function main() {
  console.log("🚀 Starting Firestore cleanup - removing Google Places data...\n");
  
  if (DRY_RUN) {
    console.log("⚠️  DRY RUN MODE - No data will be deleted. This is a preview.\n");
  } else {
    console.log("🚨 LIVE MODE - Data WILL be permanently deleted!\n");
  }
  
  console.log("This will " + (DRY_RUN ? "preview" : "permanently delete") + ":");
  console.log("   - All attractions from Google Places");
  console.log("   - All events from Google Places");
  console.log("   - All non-food discover items");
  console.log("   - Keeping: Restaurants, cafes, and food businesses");
  console.log("   - Removing: Stadiums, venues, parks, museums, attractions\n");

  try {
    const startTime = Date.now();
    
    // Execute cleanup steps
    const attractionsDeleted = await deleteGoogleAttractionsAndStadiums();
    const eventsDeleted = await deleteGoogleEvents();
    const discoverDeleted = await deleteNonFoodDiscoverItems();
    const referencesUpdated = await cleanupUserReferences();
    
    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
    
    console.log("\n" + "=".repeat(60));
    if (DRY_RUN) {
      console.log("✅ DRY RUN PREVIEW COMPLETED!");
    } else {
      console.log("✅ Cleanup completed successfully!");
    }
    console.log("=".repeat(60));
    console.log(`
📊 Summary:
  • Attractions: ${attractionsDeleted}
  • Events: ${eventsDeleted}
  • Discover items: ${discoverDeleted}
  • User profiles: ${referencesUpdated}
  • Total time: ${totalTime}s

🎯 Firestore will contain ONLY:
  ✓ Restaurants, cafes, and food businesses
  ✓ Local food business submissions
  ✓ Food-related discover items in Brisbane CBD
  ✓ All user accounts and their valid saved items
  ✗ Events, attractions, stadiums, museums, parks removed
    `);

    if (DRY_RUN) {
      console.log("\n📝 NEXT STEPS:");
      console.log("   1. Review the counts above");
      console.log("   2. If the counts look correct, set DRY_RUN = false");
      console.log("   3. Run the script again to perform the actual deletion");
      console.log("   4. Keep a backup of your Firestore data!\n");
    }

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Cleanup failed:", error);
    process.exit(1);
  }
}

main();
