/**
 * monitor_google_listings.js
 * 
 * Cloud Function to monitor Google listings and compare against BrisConnect data.
 * 
 * Reads: food_businesses, businesses collections
 * Writes: google_listing_monitoring collection (new audit trail)
 * Updates: food_businesses, businesses (lastGoogleCheckAtMs, googleSyncStatus only)
 * 
 * Does NOT automatically modify business data. All comparisons stored for admin review.
 */

const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

/**
 * Normalizes phone numbers for comparison
 * Extracts only digits for easier matching
 */
function normalizePhone(phone) {
  if (!phone) return '';
  return String(phone).replace(/\D/g, '');
}

/**
 * Normalizes URLs for comparison
 */
function normalizeUrl(url) {
  if (!url) return '';
  try {
    const u = new URL(String(url).startsWith('http') ? url : `https://${url}`);
    return u.hostname + u.pathname;
  } catch (e) {
    return String(url).toLowerCase().trim();
  }
}

/**
 * Normalizes text for similarity comparison
 */
function normalizeText(text) {
  if (!text) return '';
  return String(text)
    .toLowerCase()
    .replace(/[^\w\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Simple Levenshtein distance for text similarity
 */
function textSimilarity(str1, str2) {
  const n1 = normalizeText(str1);
  const n2 = normalizeText(str2);
  
  if (n1 === n2) return 1.0;
  if (!n1 || !n2) return 0;
  
  const longer = n1.length > n2.length ? n1 : n2;
  const shorter = n1.length > n2.length ? n2 : n1;
  
  const editDistance = getEditDistance(shorter, longer);
  return (longer.length - editDistance) / longer.length;
}

/**
 * Calculate edit distance between two strings
 */
function getEditDistance(s1, s2) {
  const costs = [];
  for (let i = 0; i <= s1.length; i++) {
    let lastValue = i;
    for (let j = 0; j <= s2.length; j++) {
      if (i === 0) {
        costs[j] = j;
      } else if (j > 0) {
        let newValue = costs[j - 1];
        if (s1.charAt(i - 1) !== s2.charAt(j - 1)) {
          newValue = Math.min(Math.min(newValue, lastValue), costs[j]) + 1;
        }
        costs[j - 1] = lastValue;
        lastValue = newValue;
      }
    }
    if (i > 0) costs[s2.length] = lastValue;
  }
  return costs[s2.length];
}

/**
 * Fetch Google Place details using Places API
 */
async function fetchGooglePlaceDetails(placeId, apiKey) {
  const endpoint = `https://places.googleapis.com/v1/places/${placeId}`;
  const fieldMask = [
    'displayName',
    'formattedAddress',
    'internationalPhoneNumber',
    'websiteUri',
    'currentOpeningHours.weekdayDescriptions',
    'businessStatus',
    'location',
    'types',
  ].join(',');

  try {
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': fieldMask,
      },
    });

    if (!response.ok) {
      logger.warn(`Google Places API error for ${placeId}:`, {
        status: response.status,
        statusText: response.statusText,
      });
      return null;
    }

    return await response.json();
  } catch (error) {
    logger.error(`Failed to fetch Google Place ${placeId}:`, error);
    return null;
  }
}

/**
 * Compare BrisConnect business data with Google Place data
 * Returns object with changes detected
 */
function compareBusinessData(brisconnectBiz, googlePlace) {
  const changes = {};
  let hasChanges = false;

  // 1. Compare business name
  const bcName = String(brisconnectBiz.name || brisconnectBiz.businessName || '').trim();
  const googleName = String(googlePlace.displayName?.text || '').trim();
  
  if (bcName && googleName) {
    const similarity = textSimilarity(bcName, googleName);
    if (similarity < 0.85) { // Less than 85% similar
      changes.name = {
        brisconnect: bcName,
        google: googleName,
        similarity: parseFloat(similarity.toFixed(2)),
        differs: true,
      };
      hasChanges = true;
    }
  }

  // 2. Compare address
  const bcAddress = String(brisconnectBiz.address || '').trim();
  const googleAddress = String(googlePlace.formattedAddress || '').trim();
  
  if (bcAddress && googleAddress) {
    // Do substring comparison - Google address is usually more complete
    const googleNorm = normalizeText(googleAddress);
    const bcNorm = normalizeText(bcAddress);
    
    if (!googleNorm.includes(bcNorm) && !bcNorm.includes(googleNorm)) {
      const similarity = textSimilarity(bcAddress, googleAddress);
      if (similarity < 0.80) {
        changes.address = {
          brisconnect: bcAddress,
          google: googleAddress,
          similarity: parseFloat(similarity.toFixed(2)),
          differs: true,
        };
        hasChanges = true;
      }
    }
  }

  // 3. Compare phone number
  const bcPhone = normalizePhone(brisconnectBiz.phone || brisconnectBiz.contactNumber);
  const googlePhone = normalizePhone(googlePlace.internationalPhoneNumber);
  
  if (bcPhone && googlePhone && bcPhone !== googlePhone) {
    changes.phone = {
      brisconnect: brisconnectBiz.phone || brisconnectBiz.contactNumber || '',
      google: googlePlace.internationalPhoneNumber || '',
      differs: true,
    };
    hasChanges = true;
  }

  // 4. Compare website
  const bcWebsite = normalizeUrl(brisconnectBiz.website);
  const googleWebsite = normalizeUrl(googlePlace.websiteUri);
  
  if (bcWebsite && googleWebsite && bcWebsite !== googleWebsite) {
    changes.website = {
      brisconnect: brisconnectBiz.website || '',
      google: googlePlace.websiteUri || '',
      differs: true,
    };
    hasChanges = true;
  }

  // 5. Compare opening hours
  const bcHours = String(brisconnectBiz.operatingHours || brisconnectBiz.businessHours || '').trim();
  const googleHours = (googlePlace.currentOpeningHours?.weekdayDescriptions || [])
    .join(' | ');
  
  if (bcHours && googleHours) {
    const similarity = textSimilarity(bcHours, googleHours);
    if (similarity < 0.80) {
      changes.hours = {
        brisconnect: bcHours,
        google: googleHours,
        similarity: parseFloat(similarity.toFixed(2)),
        differs: true,
      };
      hasChanges = true;
    }
  }

  // 6. Check business status (CRITICAL)
  const googleStatus = googlePlace.businessStatus || 'OPERATIONAL';
  if (googleStatus === 'CLOSED_PERMANENTLY' || googleStatus === 'CLOSED_TEMPORARILY') {
    changes.businessStatus = {
      brisconnect: 'active',
      google: googleStatus,
      differs: true,
      critical: googleStatus === 'CLOSED_PERMANENTLY',
    };
    hasChanges = true;
  }

  return { changes, hasChanges };
}

/**
 * Determine alert severity based on changes
 */
function determineSeverity(changes) {
  if (changes.businessStatus?.critical) {
    return 'critical'; // Business is permanently closed
  }
  if (Object.keys(changes).length > 2) {
    return 'attention'; // Multiple fields differ
  }
  if (changes.phone || changes.website || changes.hours) {
    return 'attention'; // Important contact info changed
  }
  return 'info'; // Minor differences
}

/**
 * Monitor Google listings for a single business
 */
async function monitorSingleBusiness(db, bizCollection, bizDoc, apiKey) {
  const businessId = bizDoc.id;
  const bizData = bizDoc.data();

  // Skip if no Google Place ID
  if (!bizData.googlePlaceId) {
    logger.warn(`Skipping ${businessId}: no googlePlaceId`);
    return null;
  }

  logger.info(`Checking ${bizCollection}/${businessId}`, {
    name: bizData.name || bizData.businessName,
    placeId: bizData.googlePlaceId,
  });

  // Fetch Google Place data
  const googlePlace = await fetchGooglePlaceDetails(bizData.googlePlaceId, apiKey);

  if (!googlePlace) {
    // API error - record it but don't fail
    const monitoringRecord = {
      businessId,
      businessName: bizData.name || bizData.businessName,
      googlePlaceId: bizData.googlePlaceId,
      businessCollection: bizCollection,
      checkTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'error',
      severity: 'attention',
      hasChanges: false,
      errorReason: 'Failed to fetch Google Place data',
      googleData: null,
      alertSent: false,
      adminReviewStatus: 'pending',
    };

    const monitoringRef = db.collection('google_listing_monitoring').doc();
    await monitoringRef.set(monitoringRecord);

    logger.warn(`Monitoring record created for ${businessId} (API error)`);
    return monitoringRef.id;
  }

  // Compare data
  const { changes, hasChanges } = compareBusinessData(bizData, googlePlace);
  const severity = determineSeverity(changes);

  let status = 'verified';
  if (hasChanges) {
    if (changes.businessStatus?.critical) {
      status = 'closed';
    } else {
      status = 'mismatch';
    }
  }

  // Create monitoring record
  const monitoringRecord = {
    businessId,
    businessName: bizData.name || bizData.businessName,
    googlePlaceId: bizData.googlePlaceId,
    businessCollection: bizCollection,
    checkTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    status,
    severity,
    hasChanges,
    ...(hasChanges && { changes }),
    googleData: {
      displayName: googlePlace.displayName?.text || null,
      formattedAddress: googlePlace.formattedAddress || null,
      internationalPhoneNumber: googlePlace.internationalPhoneNumber || null,
      websiteUri: googlePlace.websiteUri || null,
      businessStatus: googlePlace.businessStatus || 'OPERATIONAL',
      location: googlePlace.location || null,
      weekdayDescriptions: googlePlace.currentOpeningHours?.weekdayDescriptions || [],
    },
    alertSent: false,
    adminReviewStatus: 'pending',
  };

  const monitoringRef = db.collection('google_listing_monitoring').doc();
  await monitoringRef.set(monitoringRecord);

  logger.info(`Monitoring record created for ${businessId}`, {
    status,
    severity,
    hasChanges,
  });

  // Update business record with sync status (minimal update)
  const now = Date.now();
  await db
    .collection(bizCollection)
    .doc(businessId)
    .update({
      lastGoogleCheckAtMs: now,
      googleSyncStatus: status,
      googleSyncLastAlertId: monitoringRef.id,
    })
    .catch((err) => {
      logger.warn(`Failed to update business ${businessId}:`, err.message);
    });

  return monitoringRef.id;
}

/**
 * Main monitoring function - process all Google businesses
 */
async function monitorAllGoogleListings(apiKey, maxDocuments = null) {
  const db = admin.firestore();
  const results = {
    processed: 0,
    verified: 0,
    mismatch: 0,
    closed: 0,
    errors: 0,
    records: [],
  };

  try {
    // Query food_businesses
    logger.info('Querying food_businesses collection');
    let query = db
      .collection('food_businesses')
      .where('isGoogleListing', '==', true)
      .where('sourceProvider', '==', 'google_places');

    if (maxDocuments) {
      query = query.limit(maxDocuments);
    }

    const foodBizSnap = await query.get();
    logger.info(`Found ${foodBizSnap.size} Google food businesses`);

    // Process each business
    for (const doc of foodBizSnap.docs) {
      try {
        const recordId = await monitorSingleBusiness(db, 'food_businesses', doc, apiKey);
        if (recordId) {
          results.records.push({
            collection: 'food_businesses',
            businessId: doc.id,
            monitoringId: recordId,
          });
          results.processed++;
        }
      } catch (error) {
        logger.error(`Error monitoring food_businesses/${doc.id}:`, error);
        results.errors++;
      }
    }

    // Query businesses collection (same logic)
    logger.info('Querying businesses collection');
    let bizQuery = db
      .collection('businesses')
      .where('isGoogleListing', '==', true)
      .where('sourceProvider', '==', 'google_places');

    if (maxDocuments) {
      // Reduce remaining budget
      bizQuery = bizQuery.limit(Math.max(0, maxDocuments - results.processed));
    }

    const bizSnap = await bizQuery.get();
    logger.info(`Found ${bizSnap.size} Google businesses`);

    for (const doc of bizSnap.docs) {
      if (maxDocuments && results.processed >= maxDocuments) {
        break;
      }

      try {
        const recordId = await monitorSingleBusiness(db, 'businesses', doc, apiKey);
        if (recordId) {
          results.records.push({
            collection: 'businesses',
            businessId: doc.id,
            monitoringId: recordId,
          });
          results.processed++;
        }
      } catch (error) {
        logger.error(`Error monitoring businesses/${doc.id}:`, error);
        results.errors++;
      }
    }

    // Count results from monitoring collection
    const monitoringSnap = await db
      .collection('google_listing_monitoring')
      .where('status', '==', 'verified')
      .limit(1000)
      .get();

    const verifiedCount = monitoringSnap.docs.filter((d) => d.data().status === 'verified').length;
    const mismatchCount = monitoringSnap.docs.filter((d) => d.data().status === 'mismatch').length;
    const closedCount = monitoringSnap.docs.filter((d) => d.data().status === 'closed').length;

    results.verified = verifiedCount;
    results.mismatch = mismatchCount;
    results.closed = closedCount;

    return results;
  } catch (error) {
    logger.error('Error in monitorAllGoogleListings:', error);
    throw error;
  }
}

module.exports = {
  monitorAllGoogleListings,
  monitorSingleBusiness,
  compareBusinessData,
  determineSeverity,
};
