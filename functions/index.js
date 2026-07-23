const admin = require('firebase-admin');
const crypto = require('node:crypto');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret, defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const twilio = require('twilio');
const { ogProxy } = require('./og_proxy');

if (!admin.apps.length) {
  admin.initializeApp();
}

const twilioAccountSid = defineString('TWILIO_ACCOUNT_SID');
const twilioMessagingServiceSid = defineString('TWILIO_MESSAGING_SERVICE_SID');
const twilioAuthToken = defineSecret('TWILIO_AUTH_TOKEN');
const twilioApiKeySid = defineSecret('TWILIO_API_KEY_SID');
const twilioApiKeySecret = defineSecret('TWILIO_API_KEY_SECRET');
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

const BRISBANE_CBD = {
  lat: -27.4679,
  lng: 153.0281,
};

const GOOGLE_IMPORT_RADIUS_METERS = 30000;

const GOOGLE_ATTRACTION_TYPES = [
  'tourist_attraction',
  'museum',
  'art_gallery',
  'park',
  'zoo',
  'aquarium',
  'amusement_park',
];

const GOOGLE_EVENT_VENUE_TYPES = [
  'stadium',
  'movie_theater',
  'night_club',
  'conference_center',
  'tourist_attraction',
];

const BCC_EVENT_SOURCES = [
  'https://www.brisbane.qld.gov.au/whats-on-and-events',
  'https://www.brisbane.qld.gov.au/whats-on-and-events/events',
];

const BCC_CULTURE_SOURCES = [
  'https://www.brisbane.qld.gov.au/things-to-see-and-do/arts-and-culture',
  'https://www.brisbane.qld.gov.au/things-to-see-and-do/history-and-heritage',
];

function createTwilioClient() {
  const accountSid = twilioAccountSid.value();
  const apiKeySid = twilioApiKeySid.value();
  const apiKeySecret = twilioApiKeySecret.value();
  const authToken = twilioAuthToken.value();

  if (apiKeySid && apiKeySecret && apiKeySid.startsWith('SK')) {
    return twilio(apiKeySid, apiKeySecret, { accountSid });
  }

  if (authToken && authToken.length > 10) {
    return twilio(accountSid, authToken);
  }

  throw new Error(
    'Missing Twilio credentials. Set TWILIO_AUTH_TOKEN or TWILIO_API_KEY_SID/TWILIO_API_KEY_SECRET.',
  );
}

function normalizePhone(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    return null;
  }

  const compact = raw.replace(/[\s()-]/g, '');
  if (/^\+[1-9]\d{7,14}$/.test(compact)) {
    return compact;
  }

  const digits = compact.replace(/\D/g, '');
  if (!digits) {
    return null;
  }

  if (digits.startsWith('61') && digits.length === 11) {
    return `+${digits}`;
  }

  if (digits.startsWith('04') && digits.length === 10) {
    return `+61${digits.slice(1)}`;
  }

  if (digits.startsWith('614') && digits.length === 11) {
    return `+${digits}`;
  }

  return /^\d{8,15}$/.test(digits) ? `+${digits}` : null;
}

function extractPhone(data) {
  return normalizePhone(data.phone || data.phoneNumber || data.mobile || '');
}

async function sendWelcomeSms(event, source) {
  logger.info('sendWelcomeSms triggered.', { source });

  const snapshot = event.data;
  if (!snapshot) {
    logger.warn('No snapshot data found for trigger.', { source });
    return;
  }

  const user = snapshot.data() || {};
  logger.info('User document data keys.', {
    source,
    document: snapshot.ref.path,
    keys: Object.keys(user),
  });

  const phone = extractPhone(user);
  if (!phone) {
    logger.info('Skipping SMS because no valid phone was found.', {
      source,
      document: snapshot.ref.path,
      rawPhone: user.phone || user.phoneNumber || user.mobile || '(none)',
    });
    return;
  }

  logger.info('Attempting to send SMS.', { source, phone });

  let client;
  try {
    client = createTwilioClient();
  } catch (err) {
    logger.error('Failed to create Twilio client.', {
      source,
      error: err instanceof Error ? err.message : String(err),
    });
    return;
  }

  const messagingServiceSid = twilioMessagingServiceSid.value();
  const body = 'Welcome to BrisConnect! Your account has been created successfully.';

  try {
    const message = await client.messages.create({
      body,
      messagingServiceSid,
      to: phone,
    });

    await snapshot.ref.set(
      {
        welcomeSms: {
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          status: message.status || 'queued',
          sid: message.sid,
          to: message.to,
          from: message.from,
          source,
        },
      },
      { merge: true },
    );

    logger.info('SMS sent successfully.', {
      source,
      document: snapshot.ref.path,
      sid: message.sid,
      to: message.to,
      status: message.status,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    await snapshot.ref.set(
      {
        welcomeSms: {
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: message,
          source,
        },
      },
      { merge: true },
    );

    logger.error('SMS delivery failed.', {
      source,
      document: snapshot.ref.path,
      phone,
      error: message,
    });
  }
}

function createRegistrationTrigger(documentPath, source) {
  return onDocumentCreated(
    {
      document: documentPath,
      region: 'australia-southeast1',
      secrets: [twilioAuthToken, twilioApiKeySid, twilioApiKeySecret],
    },
    (event) => sendWelcomeSms(event, source),
  );
}

exports.sendSmsOnLocalRegister = createRegistrationTrigger(
  'local_users/{userId}',
  'local_users',
);

exports.sendSmsOnVisitorRegister = createRegistrationTrigger(
  'visitor_users/{userId}',
  'visitor_users',
);

exports.processSmsQueue = onDocumentCreated(
  {
    document: 'sms_queue/{docId}',
    region: 'australia-southeast1',
    secrets: [twilioAuthToken, twilioApiKeySid, twilioApiKeySecret],
  },
  async (event) => {
    logger.info('processSmsQueue triggered.', { docId: event.params.docId });

    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('processSmsQueue: No snapshot data.');
      return;
    }

    const data = snapshot.data() || {};
    const to = data.to;
    const message = data.message;

    if (!to || !message) {
      logger.warn('processSmsQueue: Missing to or message field.', {
        document: snapshot.ref.path,
        hasTo: !!to,
        hasMessage: !!message,
      });
      await snapshot.ref.set({ status: 'failed', error: 'Missing to or message' }, { merge: true });
      return;
    }

    let client;
    try {
      client = createTwilioClient();
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      logger.error('processSmsQueue: Failed to create Twilio client.', { error: errMsg });
      await snapshot.ref.set(
        { status: 'failed', error: errMsg, processedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );
      return;
    }

    const messagingServiceSid = twilioMessagingServiceSid.value();

    try {
      // Always route through the Messaging Service so the registered
      // BrisConnect alpha sender ID in the sender pool is used automatically.
      const rawBody = String(message);
      const prefixedBody = rawBody.startsWith('BrisConnect') ? rawBody : `BrisConnect: ${rawBody}`;
      const msgParams = {
        body: prefixedBody,
        to: String(to),
        messagingServiceSid,
      };
      const result = await client.messages.create(msgParams);

      await snapshot.ref.set(
        {
          status: result.status || 'queued',
          sid: result.sid,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.info('processSmsQueue: SMS sent.', {
        document: snapshot.ref.path,
        sid: result.sid,
        to,
        status: result.status,
      });
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);

      await snapshot.ref.set(
        {
          status: 'failed',
          error: errMsg,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.error('processSmsQueue: SMS delivery failed.', {
        document: snapshot.ref.path,
        to,
        error: errMsg,
      });
    }
  },
);

function truncateText(value, maxLength = 180) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (!text) {
    return '';
  }
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, maxLength - 1).trim()}...`;
}

function stripHtmlTags(html) {
  return String(html || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeUrl(rawUrl, baseUrl) {
  const input = String(rawUrl || '').trim();
  if (!input) {
    return '';
  }

  try {
    return new URL(input, baseUrl).toString();
  } catch (_) {
    return '';
  }
}

function documentIdForSource(section, sourceUrl, title) {
  const slug = slugify(title).slice(0, 60);
  return `bcc-${section}-${slug}`;
}

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function degreesToRadians(value) {
  return (value * Math.PI) / 180;
}

function distanceKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;
  const dLat = degreesToRadians(lat2 - lat1);
  const dLon = degreesToRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degreesToRadians(lat1)) *
      Math.cos(degreesToRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

async function fetchGooglePlacesByType(type) {
  const key = googlePlacesApiKey.value();
  const endpoint = 'https://places.googleapis.com/v1/places:searchNearby';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': [
        'places.id',
        'places.displayName',
        'places.formattedAddress',
        'places.location',
        'places.types',
        'places.rating',
        'places.userRatingCount',
        'places.photos.name',
        'places.websiteUri',
      ].join(','),
    },
    body: JSON.stringify({
      includedTypes: [type],
      maxResultCount: 20,
      locationRestriction: {
        circle: {
          center: {
            latitude: BRISBANE_CBD.lat,
            longitude: BRISBANE_CBD.lng,
          },
          radius: GOOGLE_IMPORT_RADIUS_METERS,
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`Google Places request failed (${response.status}) for type ${type}`);
  }

  const payload = await response.json();
  if (payload.error && payload.error.message) {
    throw new Error(
      `Google Places response error for type ${type}: ${payload.error.message}`,
    );
  }

  return Array.isArray(payload.places) ? payload.places : [];
}

async function fetchBrisbaneAddressAutocomplete(input, sessionToken, limit) {
  async function fetchFromNominatim() {
    const nominatimEndpoint = new URL('https://nominatim.openstreetmap.org/search');
    nominatimEndpoint.searchParams.set('q', input);
    nominatimEndpoint.searchParams.set('format', 'jsonv2');
    nominatimEndpoint.searchParams.set('countrycodes', 'au');
    nominatimEndpoint.searchParams.set('addressdetails', '1');
    nominatimEndpoint.searchParams.set('dedupe', '1');
    nominatimEndpoint.searchParams.set('bounded', '1');
    nominatimEndpoint.searchParams.set('viewbox', '152.6,-26.8,153.6,-28.2');
    nominatimEndpoint.searchParams.set('limit', String(limit));

    const nominatimResponse = await fetch(nominatimEndpoint.toString(), {
      headers: {
        'Accept-Language': 'en-AU',
        'User-Agent': 'BrisConnect/1.0 (brisconnect-app)',
      },
    });

    if (!nominatimResponse.ok) {
      throw new Error(`Nominatim autocomplete failed (${nominatimResponse.status})`);
    }

    const nominatimPayload = await nominatimResponse.json();
    const items = Array.isArray(nominatimPayload) ? nominatimPayload : [];
    const formatted = items
      .map((item) => String(item && item.display_name ? item.display_name : '').trim())
      .filter((item) => item.length > 0)
      .filter((item) => item.toLowerCase().includes('brisbane') || item.toLowerCase().includes('qld'));

    const unique = [...new Set(formatted)];
    return unique.slice(0, limit);
  }

  const key = googlePlacesApiKey.value();
  const endpoint = 'https://places.googleapis.com/v1/places:autocomplete';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': [
        'suggestions.placePrediction.text',
        'suggestions.placePrediction.structuredFormat',
      ].join(','),
    },
    body: JSON.stringify({
      input,
      sessionToken,
      includedRegionCodes: ['au'],
      languageCode: 'en-AU',
      locationBias: {
        circle: {
          center: {
            latitude: BRISBANE_CBD.lat,
            longitude: BRISBANE_CBD.lng,
          },
          radius: 35000,
        },
      },
      origin: {
        latitude: BRISBANE_CBD.lat,
        longitude: BRISBANE_CBD.lng,
      },
      includeQueryPredictions: false,
    }),
  });

  // Fallback to legacy endpoint if Places API (New) autocomplete is restricted.
  if (!response.ok) {
    const legacyEndpoint = new URL('https://maps.googleapis.com/maps/api/place/autocomplete/json');
    legacyEndpoint.searchParams.set('input', input);
    legacyEndpoint.searchParams.set('key', key);
    legacyEndpoint.searchParams.set('sessiontoken', sessionToken);
    legacyEndpoint.searchParams.set('language', 'en-AU');
    legacyEndpoint.searchParams.set('components', 'country:au');
    legacyEndpoint.searchParams.set('location', `${BRISBANE_CBD.lat},${BRISBANE_CBD.lng}`);
    legacyEndpoint.searchParams.set('radius', '35000');
    legacyEndpoint.searchParams.set('types', 'address');

    let legacyError = null;
    try {
      const legacyResponse = await fetch(legacyEndpoint.toString());
      if (!legacyResponse.ok) {
        throw new Error(
          `Google Places autocomplete failed (${response.status}) and legacy failed (${legacyResponse.status})`,
        );
      }

      const legacyPayload = await legacyResponse.json();
      const legacyStatus = String(legacyPayload.status || '');
      if (legacyStatus !== 'OK' && legacyStatus !== 'ZERO_RESULTS') {
        const legacyMessage = legacyPayload.error_message
          ? `: ${legacyPayload.error_message}`
          : '';
        throw new Error(
          `Google Places legacy autocomplete error (${legacyStatus || 'UNKNOWN'})${legacyMessage}`,
        );
      }

      const predictions = Array.isArray(legacyPayload.predictions)
        ? legacyPayload.predictions
        : [];

      const legacyFormatted = predictions
        .map((item) => String(item && item.description ? item.description : '').trim())
        .filter((item) => item.toLowerCase().includes('brisbane') || item.toLowerCase().includes('qld'));

      const legacyUnique = [...new Set(legacyFormatted)];
      return legacyUnique.slice(0, limit);
    } catch (error) {
      legacyError = error;
    }

    const fallbackSuggestions = await fetchFromNominatim();
    if (fallbackSuggestions.length > 0) {
      return fallbackSuggestions;
    }

    if (legacyError) {
      throw legacyError;
    }
    throw new Error(`Google Places autocomplete failed (${response.status})`);
  }

  const payload = await response.json();
  if (payload.error && payload.error.message) {
    throw new Error(`Google Places autocomplete error: ${payload.error.message}`);
  }

  const suggestions = Array.isArray(payload.suggestions) ? payload.suggestions : [];
  const formatted = suggestions
    .map((item) => {
      const placePrediction = item && item.placePrediction ? item.placePrediction : null;
      const primary =
        placePrediction && placePrediction.text && placePrediction.text.text
          ? String(placePrediction.text.text).trim()
          : '';
      const secondary =
        placePrediction &&
        placePrediction.structuredFormat &&
        placePrediction.structuredFormat.secondaryText &&
        placePrediction.structuredFormat.secondaryText.text
          ? String(placePrediction.structuredFormat.secondaryText.text).trim()
          : '';

      if (!primary) {
        return '';
      }

      if (!secondary) {
        return primary;
      }

      return `${primary}, ${secondary}`;
    })
    .filter(Boolean);

  const unique = [...new Set(formatted)];
  return unique.slice(0, limit);
}

function normalizePlacePhotoUrl(photoRef) {
  const reference = String(photoRef || '').trim();
  if (!reference) {
    return '';
  }

  const key = googlePlacesApiKey.value().replace(/\r?\n/g, '');
  if (reference.startsWith('places/')) {
    const endpoint = new URL(`https://places.googleapis.com/v1/${reference}/media`);
    endpoint.searchParams.set('key', key);
    endpoint.searchParams.set('maxWidthPx', '1000');
    return endpoint.toString();
  }

  const endpoint = new URL('https://maps.googleapis.com/maps/api/place/photo');
  endpoint.searchParams.set('key', key);
  endpoint.searchParams.set('photoreference', reference);
  endpoint.searchParams.set('maxwidth', '1000');
  return endpoint.toString();
}

function extractPlaceCoordinates(place) {
  const loc = (place && place.location) || (place && place.geometry && place.geometry.location);
  const lat =
    loc && typeof loc.latitude === 'number'
      ? loc.latitude
      : loc && typeof loc.lat === 'number'
        ? loc.lat
        : null;
  const lng =
    loc && typeof loc.longitude === 'number'
      ? loc.longitude
      : loc && typeof loc.lng === 'number'
        ? loc.lng
        : null;
  if (lat == null || lng == null) {
    return null;
  }
  return { lat, lng };
}

function normalizeGooglePlaceRecord(place) {
  const placeId = String(place.id || place.place_id || '').trim();
  const name = String(
    (place.displayName && place.displayName.text) || place.name || '',
  ).trim();
  const address = String(
    place.formattedAddress || place.vicinity || place.formatted_address || '',
  ).trim();
  const types = Array.isArray(place.types)
    ? place.types.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  const photoReference =
    Array.isArray(place.photos) && place.photos.length > 0
      ? place.photos[0].name || place.photos[0].photo_reference || ''
      : '';
  const rating =
    typeof place.rating === 'number' ? place.rating : null;
  const userRatingCount =
    typeof place.userRatingCount === 'number'
      ? place.userRatingCount
      : typeof place.user_ratings_total === 'number'
        ? place.user_ratings_total
        : 0;
  const websiteUri = String(place.websiteUri || place.url || '').trim();

  return {
    placeId,
    name,
    address,
    types,
    photoReference,
    rating,
    userRatingCount,
    websiteUri,
  };
}

function withinBrisbaneRadius(place) {
  const coords = extractPlaceCoordinates(place);
  if (!coords) {
    return false;
  }

  return (
    distanceKm(BRISBANE_CBD.lat, BRISBANE_CBD.lng, coords.lat, coords.lng) <=
    GOOGLE_IMPORT_RADIUS_METERS / 1000
  );
}

function mapGooglePlaceToAttraction(place) {
  const coords = extractPlaceCoordinates(place);
  if (!coords) {
    return null;
  }

  const normalized = normalizeGooglePlaceRecord(place);
  const { placeId, name, address, types, photoReference, rating, userRatingCount, websiteUri } = normalized;
  if (!placeId || !name) {
    return null;
  }

  return {
    id: `google-attraction-${slugify(name)}`,
    name,
    description: `Imported from Google Places. Rating: ${rating ?? 'N/A'} (${userRatingCount} reviews).`,
    location: address || 'Brisbane',
    latitude: coords.lat,
    longitude: coords.lng,
    category: 'Google Places',
    webLink: websiteUri,
    imageUrl: normalizePlacePhotoUrl(photoReference),
    sourceProvider: 'google_places',
    sourcePlaceId: placeId,
    sourceTypes: types,
    approvalStatus: 'approved',
    status: 'approved',
    isApproved: true,
    importedBy: 'google_places_import',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function mapGooglePlaceToEvent(place) {
  const coords = extractPlaceCoordinates(place);
  if (!coords) {
    return null;
  }

  const normalized = normalizeGooglePlaceRecord(place);
  const { placeId, name, address, types, photoReference } = normalized;
  if (!placeId || !name) {
    return null;
  }

  return {
    id: `google-event-${slugify(name)}`,
    title: `${name} (Venue)` ,
    date: 'TBA',
    time: 'TBA',
    category: 'Venue',
    location: address || 'Brisbane',
    venue: name,
    suburb: 'Brisbane',
    description:
      'Imported event venue from Google Places. Add event schedule details in admin review as needed.',
    latitude: coords.lat,
    longitude: coords.lng,
    imageUrl: normalizePlacePhotoUrl(photoReference),
    sourceProvider: 'google_places',
    sourcePlaceId: placeId,
    sourceTypes: types,
    reviewStatus: 'approved',
    approvalStatus: 'approved',
    status: 'approved',
    badge: 'Approved',
    isApproved: true,
    importedBy: 'google_places_import',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function dedupeBySourcePlaceId(records) {
  const unique = new Map();
  for (const item of records) {
    if (!item || !item.sourcePlaceId) {
      continue;
    }
    unique.set(item.sourcePlaceId, item);
  }
  return [...unique.values()];
}

async function importGooglePlacesCatalog() {
  const db = admin.firestore();

  const attractionResultsNested = [];
  for (const type of GOOGLE_ATTRACTION_TYPES) {
    try {
      const results = await fetchGooglePlacesByType(type);
      attractionResultsNested.push(results);
    } catch (error) {
      logger.warn('Google Places attraction import failed for type.', {
        type,
        error: String(error),
      });
    }
  }

  const venueResultsNested = [];
  for (const type of GOOGLE_EVENT_VENUE_TYPES) {
    try {
      const results = await fetchGooglePlacesByType(type);
      venueResultsNested.push(results);
    } catch (error) {
      logger.warn('Google Places event import failed for type.', {
        type,
        error: String(error),
      });
    }
  }

  const attractionPlaces = attractionResultsNested
    .flat()
    .filter(withinBrisbaneRadius)
    .map(mapGooglePlaceToAttraction)
    .filter(Boolean);

  const eventPlaces = venueResultsNested
    .flat()
    .filter(withinBrisbaneRadius)
    .map(mapGooglePlaceToEvent)
    .filter(Boolean);

  const attractions = dedupeBySourcePlaceId(attractionPlaces);
  const events = dedupeBySourcePlaceId(eventPlaces);

  const allWrites = [];
  for (const attraction of attractions) {
    allWrites.push({ collection: 'attractions', record: attraction });
  }
  for (const event of events) {
    allWrites.push({ collection: 'events', record: event });
  }

  let writeCount = 0;
  const chunkSize = 400;
  for (let index = 0; index < allWrites.length; index += chunkSize) {
    const chunk = allWrites.slice(index, index + chunkSize);
    const batch = db.batch();

    for (const item of chunk) {
      const ref = db.collection(item.collection).doc(item.record.id);
      batch.set(ref, item.record, { merge: true });
      writeCount += 1;
    }

    await batch.commit();
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('seed_metadata').doc('google_places_import').set(
    {
      sourceProvider: 'google_places',
      center: BRISBANE_CBD,
      radiusMeters: GOOGLE_IMPORT_RADIUS_METERS,
      attractionCount: attractions.length,
      eventCount: events.length,
      writeCount,
      lastSyncedAt: now,
    },
    { merge: true },
  );

  return {
    center: BRISBANE_CBD,
    radiusKm: GOOGLE_IMPORT_RADIUS_METERS / 1000,
    attractionCount: attractions.length,
    eventCount: events.length,
    writeCount,
  };
}

function parseDateString(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    return { date: '', time: '' };
  }

  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return { date: raw, time: '' };
  }

  const date = `${String(parsed.getDate()).padStart(2, '0')}/${String(
    parsed.getMonth() + 1,
  ).padStart(2, '0')}/${parsed.getFullYear()}`;

  let hour = parsed.getHours();
  const suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12 || 12;
  const time = `${hour}:${String(parsed.getMinutes()).padStart(2, '0')} ${suffix}`;

  return { date, time };
}

function extractJsonLdObjects(html) {
  const blocks = [...String(html || '').matchAll(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)];
  const items = [];

  for (const block of blocks) {
    const payload = block[1] || '';
    try {
      const parsed = JSON.parse(payload);
      if (Array.isArray(parsed)) {
        items.push(...parsed);
      } else {
        items.push(parsed);
      }
    } catch (_) {
      // Ignore malformed JSON-LD blocks.
    }
  }

  return items.filter(Boolean);
}

function extractMetaDescription(html) {
  const match = String(html || '').match(/<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["'][^>]*>/i);
  return match ? truncateText(match[1], 220) : '';
}

function extractMetaContent(html, attributeName, attributeValue) {
  const escapedName = String(attributeName || '').replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
  const escapedValue = String(attributeValue || '').replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
  const pattern = new RegExp(
    `<meta[^>]*${escapedName}=["']${escapedValue}["'][^>]*content=["']([^"']+)["'][^>]*>`,
    'i',
  );
  const match = String(html || '').match(pattern);
  return match ? String(match[1] || '').trim() : '';
}

function firstImageFromJsonLd(value, baseUrl) {
  if (!value) {
    return '';
  }

  if (typeof value === 'string') {
    return normalizeUrl(value, baseUrl);
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = firstImageFromJsonLd(item, baseUrl);
      if (found) {
        return found;
      }
    }
    return '';
  }

  if (typeof value === 'object') {
    const objectValue = value;
    const direct = normalizeUrl(objectValue.url || objectValue.contentUrl || '', baseUrl);
    if (direct) {
      return direct;
    }
  }

  return '';
}

function extractInlineImageFromHtml(html, baseUrl) {
  const matches = [...String(html || '').matchAll(/<img[^>]*>/gi)];
  for (const match of matches) {
    const tag = String(match[0] || '');
    const srcMatch = tag.match(/(?:src|data-src|data-original)=["']([^"']+)["']/i);
    if (!srcMatch) {
      continue;
    }

    const candidate = normalizeUrl(srcMatch[1], baseUrl);
    if (!candidate) {
      continue;
    }

    const lower = candidate.toLowerCase();
    if (
      lower.includes('logo') ||
      lower.includes('icon') ||
      lower.includes('sprite') ||
      lower.endsWith('.svg')
    ) {
      continue;
    }

    return candidate;
  }

  return '';
}

function extractPrimaryImage(html, baseUrl) {
  const ogImage = normalizeUrl(extractMetaContent(html, 'property', 'og:image'), baseUrl);
  if (ogImage) {
    return ogImage;
  }

  const twitterImage = normalizeUrl(extractMetaContent(html, 'name', 'twitter:image'), baseUrl);
  if (twitterImage) {
    return twitterImage;
  }

  return extractInlineImageFromHtml(html, baseUrl);
}

function extractAnchors(html, baseUrl) {
  const matches = [...String(html || '').matchAll(/<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)];
  const anchors = [];

  for (const match of matches) {
    const href = normalizeUrl(match[1], baseUrl);
    const anchorInnerHtml = String(match[2] || '');
    const label = truncateText(stripHtmlTags(anchorInnerHtml), 120);
    const imageCandidateMatch = anchorInnerHtml.match(/<img[^>]*(?:src|data-src|data-original)=["']([^"']+)["'][^>]*>/i);
    const imageUrl = normalizeUrl(imageCandidateMatch ? imageCandidateMatch[1] : '', baseUrl);
    if (!href || !label) {
      continue;
    }
    anchors.push({ href, label, imageUrl });
  }

  return anchors;
}

async function fetchPage(url) {
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'BrisConnectBot/1.0 (+https://github.com/)',
      Accept: 'text/html,application/xhtml+xml',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch ${url} (status ${response.status})`);
  }

  return response.text();
}

function mapEventJsonLd(item, sourcePage, fallbackDescription) {
  const title = truncateText(item.name || '', 120);
  const eventUrl = normalizeUrl(item.url || sourcePage, sourcePage) || sourcePage;
  const imageUrl = firstImageFromJsonLd(item.image, sourcePage);
  if (!title || !eventUrl) {
    return null;
  }

  const start = parseDateString(item.startDate || item.endDate || '');
  const place = item.location && typeof item.location === 'object' ? item.location : {};
  const address = place.address && typeof place.address === 'object' ? place.address : {};
  const venue = truncateText(place.name || '', 90);
  const suburb = truncateText(address.addressLocality || address.addressRegion || 'Brisbane', 80);

  return {
    id: documentIdForSource('events', eventUrl, title),
    sourceProvider: 'brisbane_city_council',
    sourceUrl: eventUrl,
    sourcePage,
    section: 'events',
    title,
    description: truncateText(item.description || fallbackDescription, 220),
    imageUrl,
    date: start.date,
    time: start.time,
    venue: venue || 'Venue TBA',
    suburb: suburb || 'Brisbane',
    location: venue || suburb || 'Brisbane',
    categories: ['bcc', 'events'],
  };
}

function mapCultureAnchor(anchor, sourcePage, fallbackDescription, fallbackImageUrl) {
  const url = anchor.href;
  const title = truncateText(anchor.label, 120);
  const imageUrl = normalizeUrl(anchor.imageUrl || fallbackImageUrl || '', sourcePage);
  if (!url || !title) {
    return null;
  }

  return {
    id: documentIdForSource('historical', url, title),
    sourceProvider: 'brisbane_city_council',
    sourceUrl: url,
    sourcePage,
    section: 'historical',
    title,
    description: truncateText(fallbackDescription || 'Source-listed culture and heritage item from Brisbane City Council.', 220),
    imageUrl,
    location: 'Brisbane',
    categories: ['bcc', 'culture-history'],
  };
}

async function collectBccCatalog() {
  const events = [];
  const historical = [];

  for (const url of BCC_EVENT_SOURCES) {
    try {
      const html = await fetchPage(url);
      const jsonLd = extractJsonLdObjects(html);
      const description = extractMetaDescription(html);
      const pageImage = extractPrimaryImage(html, url);

      for (const item of jsonLd) {
        const type = String(item['@type'] || '').toLowerCase();
        if (type !== 'event') {
          continue;
        }
        const mapped = mapEventJsonLd(item, url, description);
        if (mapped) {
          if (!mapped.imageUrl) {
            mapped.imageUrl = pageImage;
          }
          events.push(mapped);
        }
      }
    } catch (error) {
      logger.warn('Event source fetch failed.', { url, error: String(error) });
    }
  }

  for (const url of BCC_CULTURE_SOURCES) {
    try {
      const html = await fetchPage(url);
      const anchors = extractAnchors(html, url);
      const description = extractMetaDescription(html);
      const pageImage = extractPrimaryImage(html, url);
      const detailImageCache = new Map();

      for (const anchor of anchors) {
        // Keep only council domain pages for sourced culture/history references.
        if (!anchor.href.includes('brisbane.qld.gov.au')) {
          continue;
        }

        let detailImage = '';
        const anchorUrl = anchor.href;
        if (anchorUrl && !detailImageCache.has(anchorUrl)) {
          try {
            const detailHtml = await fetchPage(anchorUrl);
            detailImage = extractPrimaryImage(detailHtml, anchorUrl);
          } catch (_) {
            detailImage = '';
          }
          detailImageCache.set(anchorUrl, detailImage);
        } else if (anchorUrl) {
          detailImage = detailImageCache.get(anchorUrl) || '';
        }

        const mapped = mapCultureAnchor(anchor, url, description, detailImage || pageImage);
        if (mapped) {
          historical.push(mapped);
        }
      }
    } catch (error) {
      logger.warn('Culture source fetch failed.', { url, error: String(error) });
    }
  }

  const dedupe = (records) => {
    const map = new Map();
    for (const record of records) {
      map.set(record.id, record);
    }
    return [...map.values()];
  };

  return {
    events: dedupe(events),
    historical: dedupe(historical),
  };
}

async function upsertBccCatalog() {
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const data = await collectBccCatalog();
  const records = [...data.events, ...data.historical];

  let writes = 0;
  const chunkSize = 400;
  for (let i = 0; i < records.length; i += chunkSize) {
    const chunk = records.slice(i, i + chunkSize);
    const batch = db.batch();

    for (const record of chunk) {
      const discoverRef = db.collection('discover_items').doc(record.id);
      batch.set(
        discoverRef,
        {
          ...record,
          approvalStatus: 'approved',
          importedBy: 'bcc_sync',
          updatedAt: now,
        },
        { merge: true },
      );
      writes += 1;

      if (record.section === 'events') {
        const eventRef = db.collection('events').doc(record.id);
        batch.set(
          eventRef,
          {
            id: record.id,
            title: record.title,
            date: record.date,
            time: record.time,
            venue: record.venue,
            suburb: record.suburb,
            description: record.description,
            imageUrl: record.imageUrl || '',
            approvalStatus: 'approved',
            sourceProvider: record.sourceProvider,
            sourceUrl: record.sourceUrl,
            updatedAt: now,
          },
          { merge: true },
        );
        writes += 1;
      }
    }

    await batch.commit();
  }

  await db.collection('seed_metadata').doc('bcc_catalog_sync').set(
    {
      sourceProvider: 'brisbane_city_council',
      lastSyncedAt: now,
      eventCount: data.events.length,
      historicalCount: data.historical.length,
      writeCount: writes,
    },
    { merge: true },
  );

  return {
    eventCount: data.events.length,
    historicalCount: data.historical.length,
    writeCount: writes,
  };
}

function determineDiscoverSection(types) {
  if (!Array.isArray(types)) {
    return 'food';
  }

  const typeStr = types.join('|').toLowerCase();

  if (
    typeStr.includes('museum') ||
    typeStr.includes('art_gallery') ||
    typeStr.includes('historical')
  ) {
    return 'historical';
  }

  if (
    typeStr.includes('stadium') ||
    typeStr.includes('night_club') ||
    typeStr.includes('movie_theater') ||
    typeStr.includes('conference_center') ||
    typeStr.includes('venue')
  ) {
    return 'stadiums';
  }

  if (
    typeStr.includes('restaurant') ||
    typeStr.includes('cafe') ||
    typeStr.includes('bar') ||
    typeStr.includes('food')
  ) {
    return 'food';
  }

  return 'food';
}

async function convertGooglePlacesToDiscoverItems() {
  const db = admin.firestore();

  const attractionsSnapshot = await db
    .collection('attractions')
    .where('sourceProvider', '==', 'google_places')
    .where('approvalStatus', '==', 'approved')
    .get();

  const eventsSnapshot = await db
    .collection('events')
    .where('sourceProvider', '==', 'google_places')
    .where('approvalStatus', '==', 'approved')
    .get();

  let itemCount = 0;
  let writeCount = 0;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const chunkSize = 400;
  const allWrites = [];

  attractionsSnapshot.docs.forEach((doc) => {
    const attraction = doc.data();
    const sourceTypes = Array.isArray(attraction.sourceTypes)
      ? attraction.sourceTypes
      : [];
    const section = determineDiscoverSection(sourceTypes);

    const discoverItem = {
      id: `discover_${attraction.id}`,
      section,
      title: attraction.name,
      description: attraction.description,
      imageUrl: attraction.imageUrl,
      location: attraction.location,
      latitude: attraction.latitude,
      longitude: attraction.longitude,
      categories: ['google_places', section, ...sourceTypes.slice(0, 3)],
      webLink: attraction.webLink,
      badge: 'Imported',
      approvalStatus: 'approved',
      sourceProvider: 'google_places',
      sourceAttractionId: attraction.id,
      sourcePlaceId: attraction.sourcePlaceId || null,
      importedFrom: 'google_places_catalog',
      updatedAt: now,
    };

    allWrites.push({ collection: 'discover_items', record: discoverItem });
    itemCount += 1;
  });

  eventsSnapshot.docs.forEach((doc) => {
    const event = doc.data();

    const discoverItem = {
      id: `discover_${event.id}`,
      section: 'events',
      title: event.title || event.venue,
      description: event.description,
      imageUrl: event.imageUrl,
      location: event.location,
      venue: event.venue,
      suburb: event.suburb,
      date: event.date,
      time: event.time,
      latitude: event.latitude,
      longitude: event.longitude,
      categories: ['google_places', 'events', 'venue'],
      badge: 'Imported',
      approvalStatus: 'approved',
      sourceProvider: 'google_places',
      sourceEventId: event.id,
      sourcePlaceId: event.sourcePlaceId || null,
      importedFrom: 'google_places_catalog',
      updatedAt: now,
    };

    allWrites.push({ collection: 'discover_items', record: discoverItem });
    itemCount += 1;
  });

  for (let index = 0; index < allWrites.length; index += chunkSize) {
    const chunk = allWrites.slice(index, index + chunkSize);
    const batch = db.batch();

    for (const item of chunk) {
      const ref = db.collection(item.collection).doc(item.record.id);
      batch.set(ref, item.record, { merge: true });
      writeCount += 1;
    }

    await batch.commit();
  }

  return {
    discoveredAttractions: attractionsSnapshot.docs.length,
    discoveredEvents: eventsSnapshot.docs.length,
    itemCount,
    writeCount,
  };
}

async function assertAdminCaller(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const email = String(request.auth.token.email || '').trim().toLowerCase();
  if (!email) {
    throw new HttpsError('permission-denied', 'Email claim is missing.');
  }

  const adminDoc = await admin.firestore().collection('admins').doc(email).get();
  if (!adminDoc.exists) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
}

exports.syncBrisbaneCouncilCatalog = onCall(
  { region: 'australia-southeast1', timeoutSeconds: 180 },
  async (request) => {
    await assertAdminCaller(request);
    const summary = await upsertBccCatalog();
    logger.info('Manual BCC sync completed.', summary);
    return summary;
  },
);

exports.testSmsSend = onCall(
  {
    region: 'australia-southeast1',
    secrets: [twilioAuthToken, twilioApiKeySid, twilioApiKeySecret],
  },
  async (request) => {
    await assertAdminCaller(request);

    const phone = request.data?.phone;
    if (!phone) {
      throw new HttpsError('invalid-argument', 'phone is required.');
    }

    const normalized = normalizePhone(phone);
    if (!normalized) {
      throw new HttpsError('invalid-argument', `Invalid phone: ${phone}`);
    }

    logger.info('testSmsSend: Starting.', { phone: normalized });

    let client;
    try {
      client = createTwilioClient();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error('testSmsSend: Twilio client failed.', { error: msg });
      return { success: false, error: msg };
    }

    const messagingServiceSid = twilioMessagingServiceSid.value();
    logger.info('testSmsSend: Sending via Twilio.', {
      phone: normalized,
      messagingServiceSid,
      accountSid: twilioAccountSid.value(),
    });

    try {
      const result = await client.messages.create({
        body: 'BrisConnect test SMS. If you receive this, SMS delivery is working.',
        messagingServiceSid,
        to: normalized,
      });

      logger.info('testSmsSend: Success.', {
        sid: result.sid,
        status: result.status,
        to: result.to,
      });

      return { success: true, sid: result.sid, status: result.status, to: result.to };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error('testSmsSend: Failed.', { error: msg, phone: normalized });
      return { success: false, error: msg };
    }
  },
);

exports.scheduledSyncBrisbaneCouncilCatalog = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: '0 */6 * * *',
    timeZone: 'Australia/Brisbane',
    timeoutSeconds: 300,
  },
  async () => {
    const summary = await upsertBccCatalog();
    logger.info('Scheduled BCC sync completed.', summary);
  },
);

exports.importGooglePlacesCatalog = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 180,
    secrets: [googlePlacesApiKey],
  },
  async (request) => {
    await assertAdminCaller(request);

    try {
      const summary = await importGooglePlacesCatalog();
      logger.info('Manual Google Places import completed.', summary);
      return summary;
    } catch (error) {
      logger.error('Google Places import failed.', { error: String(error) });
      throw new HttpsError(
        'internal',
        `Google Places import failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

exports.convertGooglePlacesToDiscoverItems = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 180,
  },
  async (request) => {
    await assertAdminCaller(request);

    try {
      const summary = await convertGooglePlacesToDiscoverItems();
      logger.info(
        'Google Places to discover items conversion completed.',
        summary,
      );
      return summary;
    } catch (error) {
      logger.error(
        'Google Places to discover items conversion failed.',
        { error: String(error) },
      );
      throw new HttpsError(
        'internal',
        `Discover items conversion failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

exports.autocompleteBrisbaneAddress = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 20,
    secrets: [googlePlacesApiKey],
  },
  async (request) => {
    const query = String((request.data && request.data.query) || '').trim();
    if (query.length < 2) {
      return { suggestions: [] };
    }

    const sessionToken = String(
      (request.data && request.data.sessionToken) ||
        `brisconnect-${Date.now()}`,
    )
      .trim()
      .slice(0, 128);

    const requestedLimit = Number((request.data && request.data.limit) || 8);
    const limit = Number.isFinite(requestedLimit)
      ? Math.max(1, Math.min(10, Math.floor(requestedLimit)))
      : 8;

    try {
      const suggestions = await fetchBrisbaneAddressAutocomplete(
        query,
        sessionToken,
        limit,
      );
      return { suggestions };
    } catch (error) {
      logger.error('autocompleteBrisbaneAddress failed.', {
        error: String(error),
        query,
      });
      throw new HttpsError(
        'internal',
        `Autocomplete failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

// ── Username → email resolution (callable without auth) ──────────────
exports.resolveUsername = onCall(
  { region: 'australia-southeast1' },
  async (request) => {
    const username = (request.data && request.data.username || '').trim().toLowerCase();
    const userType = (request.data && request.data.userType || '').trim().toLowerCase();

    if (!username || !['visitor', 'local'].includes(userType)) {
      return { email: null };
    }

    const collection = userType === 'visitor' ? 'visitor_users' : 'local_users';

    try {
      const snapshot = await admin.firestore().collection(collection).get();
      let matchedEmail = null;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const email = (data.email || doc.id).trim().toLowerCase();
        const docUsername = (data.username || email.split('@')[0]).trim().toLowerCase();

        if (docUsername !== username) continue;

        if (matchedEmail && matchedEmail !== email) {
          return { email: null, error: 'duplicate' };
        }
        matchedEmail = email;
      }

      return { email: matchedEmail };
    } catch (error) {
      logger.error('resolveUsername failed', { error: String(error) });
      return { email: null };
    }
  },
);

// ── Google Places Details / Find Place helpers ───────────────────────────────
async function fetchPlaceIdFromText(input, key) {
  const endpoint = new URL('https://places.googleapis.com/v1/places:searchText');
  const response = await fetch(endpoint.toString(), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': 'places.id,places.formattedAddress,places.location',
    },
    body: JSON.stringify({
      textQuery: input,
      locationBias: {
        circle: {
          center: {
            latitude: BRISBANE_CBD.lat,
            longitude: BRISBANE_CBD.lng,
          },
          radius: 35000,
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`Google Places searchText failed (${response.status})`);
  }

  const payload = await response.json();
  const places = Array.isArray(payload.places) ? payload.places : [];
  if (places.length === 0) {
    return null;
  }

  const place = places[0];
  return {
    placeId: place.id || null,
    formattedAddress: place.formattedAddress || null,
    lat: place.location?.latitude ?? null,
    lng: place.location?.longitude ?? null,
  };
}

async function fetchPlaceDetails(placeId, key) {
  const endpoint = new URL(`https://places.googleapis.com/v1/places/${placeId}`);
  endpoint.searchParams.set('key', key);

  const response = await fetch(endpoint.toString(), {
    method: 'GET',
    headers: {
      'X-Goog-FieldMask': 'id,formattedAddress,location',
    },
  });

  if (!response.ok) {
    throw new Error(`Google Places details failed (${response.status})`);
  }

  const payload = await response.json();
  return {
    placeId: payload.id || placeId,
    formattedAddress: payload.formattedAddress || null,
    lat: payload.location?.latitude ?? null,
    lng: payload.location?.longitude ?? null,
  };
}

exports.findPlaceByText = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 15,
    secrets: [googlePlacesApiKey],
  },
  async (request) => {
    const query = String((request.data && request.data.query) || '').trim();
    if (query.length < 3) {
      return { placeId: null };
    }

    try {
      const key = googlePlacesApiKey.value();
      const result = await fetchPlaceIdFromText(query, key);
      return { placeId: result?.placeId || null };
    } catch (error) {
      logger.error('findPlaceByText failed.', {
        error: String(error),
        query,
      });
      throw new HttpsError(
        'internal',
        `Find place failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

exports.getPlaceDetails = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 15,
    secrets: [googlePlacesApiKey],
  },
  async (request) => {
    const placeId = String((request.data && request.data.placeId) || '').trim();
    if (!placeId) {
      throw new HttpsError('invalid-argument', 'placeId is required.');
    }

    try {
      const key = googlePlacesApiKey.value();
      const details = await fetchPlaceDetails(placeId, key);
      if (details.lat == null || details.lng == null) {
        throw new Error('Place details missing coordinates.');
      }
      return {
        placeId: details.placeId,
        formattedAddress: details.formattedAddress,
        lat: details.lat,
        lng: details.lng,
      };
    } catch (error) {
      logger.error('getPlaceDetails failed.', {
        error: String(error),
        placeId,
      });
      throw new HttpsError(
        'internal',
        `Place details failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

// ── Trending / Buzz Score computation ────────────────────────────────────────
const TRENDING_THRESHOLD = 70; // Minimum buzzScore to be marked as trending
const TRENDING_DECAY_DAYS = 7; // Views/reviews older than this contribute less

function calculateBuzzScore({ viewCount, reviewCount, averageRating, buzzRatings }) {
  const ratingScore = Math.min((averageRating || 0) / 5, 1) * 30; // up to 30
  const reviewScore = Math.min(reviewCount || 0, 50) * 0.8; // up to 40
  const viewScore = Math.min(viewCount || 0, 500) * 0.04; // up to 20
  const buzzRatingScore = buzzRatings.length > 0
    ? (buzzRatings.reduce((a, b) => a + b, 0) / buzzRatings.length) * 2 // up to 10
    : 0;

  return Math.round(ratingScore + reviewScore + viewScore + buzzRatingScore);
}

async function recalculateBusinessBuzzScore(businessId) {
  const db = admin.firestore();
  const businessRef = db.collection('businesses').doc(businessId);
  const businessDoc = await businessRef.get();
  if (!businessDoc.exists) return;

  const businessData = businessDoc.data() || {};

  // Aggregate approved reviews
  const reviewsSnap = await db
    .collection('reviews')
    .where('businessId', '==', businessId)
    .where('isReported', '==', false)
    .get();

  const reviewCount = reviewsSnap.size;
  const ratings = reviewsSnap.docs.map((d) => Number(d.data().rating || 0)).filter((r) => r > 0);
  const averageRating = ratings.length > 0
    ? ratings.reduce((a, b) => a + b, 0) / ratings.length
    : 0;
  const buzzRatings = reviewsSnap.docs
    .map((d) => Number(d.data().buzzRating || 0))
    .filter((r) => r > 0);

  const viewCount = Number(businessData.viewCount || 0);
  const buzzScore = calculateBuzzScore({
    viewCount,
    reviewCount,
    averageRating,
    buzzRatings,
  });

  await businessRef.update({
    buzzScore,
    isTrending: buzzScore >= TRENDING_THRESHOLD,
    reviewCount,
    rating: averageRating,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('Recalculated buzz score.', { businessId, buzzScore, isTrending: buzzScore >= TRENDING_THRESHOLD });
}

// Recalculate buzz score when a review is created or updated.
exports.onReviewChanged = onDocumentCreated(
  {
    region: 'australia-southeast1',
    document: 'reviews/{reviewId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = data.businessId;
    if (!businessId) {
      logger.warn('Review created without businessId.', { reviewId: event.params.reviewId });
      return;
    }
    await recalculateBusinessBuzzScore(businessId);
  },
);

// Recalculate buzz score when a business is viewed (viewCount incremented).
exports.onBusinessViewed = onDocumentCreated(
  {
    region: 'australia-southeast1',
    document: 'business_views/{viewId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = data.businessId;
    if (!businessId) {
      logger.warn('Business view without businessId.', { viewId: event.params.viewId });
      return;
    }
    await recalculateBusinessBuzzScore(businessId);
  },
);

// Scheduled job to refresh trending scores every 5 minutes and catch any drift.
exports.refreshTrendingScores = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 5 minutes',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const businessesSnap = await db.collection('businesses').where('isVerified', '==', true).get();

    const promises = businessesSnap.docs.map((doc) => recalculateBusinessBuzzScore(doc.id));
    await Promise.all(promises);

    logger.info('Scheduled trending refresh complete.', {
      count: businessesSnap.size,
    });
  },
);

// ── AI Post Generator (callable, uses Google Gemini API) ─────────────────────
const geminiApiKey = defineSecret('GEMINI_API_KEY');

async function callGemini(prompt) {
  const apiKey = geminiApiKey.value();
  if (!apiKey || apiKey.length < 10) {
    throw new Error('GEMINI_API_KEY is not configured.');
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
  const body = JSON.stringify({
    contents: [
      {
        role: 'user',
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      temperature: 0.85,
      maxOutputTokens: 400,
      topP: 0.95,
      topK: 40,
    },
  });

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API error ${response.status}: ${errorText}`);
  }

  const json = await response.json();
  const candidates = json.candidates || [];
  if (candidates.length === 0) {
    throw new Error('Gemini returned no candidates.');
  }

  const parts = candidates[0].content?.parts || [];
  const text = parts.map((part) => part.text || '').join('').trim();
  if (!text) {
    throw new Error('Gemini returned empty content.');
  }
  return text;
}

function buildPrompt(postType, businessName, category, extraContext) {
  const base = `You are a witty, energetic social media marketer for local Brisbane businesses.
Write ONE short, exciting, fun Facebook/Instagram post for "${businessName}"${category ? ` (${category})` : ''}.
Use emojis, keep it under 280 words, and make locals feel FOMO.
Tone: friendly, punchy, and authentically Brisbane.
Do not include markdown or bullet lists. Return only the post text.`;

  const typeGuidance = {
    Promotion: 'Focus on the deal, why it is irresistible, and urgency.',
    'Menu Item': 'Make the dish sound mouth-watering and worth visiting for.',
    'Business Event': 'Hype the event, who should come, and what to expect.',
    Announcement: 'Make the news feel personal and celebratory.',
    'Review Highlight': 'Turn a great customer moment into a humble brag.',
  };

  const lines = [base];
  const guidance = typeGuidance[postType] || 'Make it engaging and shareable.';
  lines.push(`Post type guidance: ${guidance}`);

  if (extraContext && extraContext.trim().length > 0) {
    lines.push(`Use these details naturally in the post:\n${extraContext.trim()}`);
  }

  lines.push('Include 3-5 relevant hashtags at the end.');
  return lines.join('\n\n');
}

function fallbackPost(postType, businessName, category, extraContext) {
  const details = extraContext.trim().split('\n').filter(Boolean);
  const detailSentence = details.length > 0
    ? ` ${details[0].replace(/^(Title|Description|Price|Discount|Date|Location):\s*/i, '')}.`
    : '';
  const safeCategory = (category || 'Brisbane').replace(/\s+/g, '');

  const openers = {
    Promotion: `🔥 Don\'t miss out, Brisbane! ${businessName} has a deal you\'ll love.${detailSentence} Grab it before it\'s gone!`,
    'Menu Item': `🤤 Craving something delicious? ${businessName} has you covered.${detailSentence} Come taste what everyone\'s talking about!`,
    'Business Event': `🎉 Something exciting is happening at ${businessName}!${detailSentence} Bring your crew and make it a night to remember.`,
    Announcement: `📣 Big news from ${businessName}!${detailSentence} We can\'t wait to share it with you.`,
    'Review Highlight': `⭐ Our customers said it best! ${businessName} is all about great vibes and even better experiences.${detailSentence}`,
  };

  return `${openers[postType] || openers.Announcement}\n\nFollow us for more updates and tag a friend who needs to see this!\n\n#Brisbane #${safeCategory} #LocalBusiness #BrisConnect`;
}

exports.generatePost = onCall(
  {
    region: 'australia-southeast1',
    secrets: [geminiApiKey],
  },
  async (request) => {
    // Dev: allow unauthenticated calls from unsigned macOS builds where Firebase
    // Auth keychain access fails.
    // if (!request.auth) {
    //   throw new HttpsError('unauthenticated', 'Must be signed in to generate posts.');
    // }

    const { postType = 'Post', businessName = '', category = '', extraContext = '' } = request.data || {};

    if (!businessName) {
      throw new HttpsError('invalid-argument', 'businessName is required.');
    }

    try {
      const prompt = buildPrompt(postType, businessName, category, extraContext);
      const post = await callGemini(prompt);
      return { post };
    } catch (error) {
      logger.warn('Gemini generation failed, using fallback.', { error: error.message, businessName });
      return { post: fallbackPost(postType, businessName, category, extraContext) };
    }
  }
);

// ── One-time backfill: mirror business/{id}/reviews to top-level reviews ─────
exports.backfillBusinessReviews = onCall(
  {
    region: 'australia-southeast1',
  },
  async (request) => {
    // Dev: allow unauthenticated calls from unsigned macOS builds.
    // Restrict to admin before running in production.
    // if (!request.auth || !request.auth.token.admin) {
    //   throw new HttpsError('permission-denied', 'Admin only');
    // }

    const db = admin.firestore();
    const businessesSnap = await db.collection('businesses').get();
    let mirrored = 0;
    let skipped = 0;

    for (const businessDoc of businessesSnap.docs) {
      const businessId = businessDoc.id;
      const reviewsSnap = await businessDoc.ref.collection('reviews').get();

      for (const reviewDoc of reviewsSnap.docs) {
        const data = reviewDoc.data();
        const createdAt = data.createdAt;

        // Avoid duplicates by checking for an existing review with the same
        // businessId, userId, rating, comment, and createdAt.
        const existing = await db
          .collection('reviews')
          .where('businessId', '==', businessId)
          .where('visitorId', '==', data.userId)
          .where('rating', '==', Math.round(data.rating || 0))
          .where('comment', '==', data.comment || '')
          .limit(1)
          .get();

        if (!existing.empty) {
          skipped += 1;
          continue;
        }

        await db.collection('reviews').add({
          businessId: businessId,
          visitorId: data.userId || 'unknown',
          visitorName: data.userName || 'Anonymous',
          rating: Math.round(data.rating || 0),
          comment: data.comment || '',
          createdAt: createdAt || admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: null,
          deletedAt: null,
          isReported: false,
          reportReason: null,
          reportedBy: null,
          deletedBy: null,
          helpfulCount: data.helpfulCount || 0,
          isFlagged: false,
          visible: true,
        });
        mirrored += 1;
      }
    }

    logger.info('Backfill complete', { mirrored, skipped });
    return { mirrored, skipped };
  }
);

// ── Email + code login ──────────────────────────────────────────────────────

const LOGIN_CODE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const LOGIN_CODE_MAX_ATTEMPTS = 5;

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function loginCodeDocId(email) {
  return email.trim().toLowerCase();
}

function getLoginEmailHtml(code, userType) {
  const title = userType === 'local' ? 'Local Account' : 'Visitor Account';
  return `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
      <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
        <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
      </div>
      <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
        <p style="font-size:16px;color:#333333;">Hello,</p>
        <p style="font-size:16px;color:#333333;">Use the code below to sign in to your BrisConnect+ ${title}:</p>
        <div style="text-align:center;margin:24px 0;">
          <span style="font-size:32px;font-weight:700;letter-spacing:8px;color:#E8820C;padding:12px 24px;background-color:#FFF5EB;border-radius:8px;">${code}</span>
        </div>
        <p style="font-size:14px;color:#666666;">This code expires in 10 minutes. If you didn't request it, you can safely ignore this email.</p>
      </div>
      <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
    </div>
  `;
}

exports.sendEmailLoginCode = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
  },
  async (request) => {
    const email = String(request.data.email || '').trim().toLowerCase();
    const userType = String(request.data.userType || '').trim().toLowerCase();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (!['visitor', 'local'].includes(userType)) {
      throw new HttpsError('invalid-argument', 'userType must be visitor or local.');
    }

    const code = generateCode();
    const codeHash = hashCode(code);
    const now = Date.now();
    const docId = loginCodeDocId(email);

    const codesRef = admin.firestore().collection('login_codes').doc(docId);
    const existing = await codesRef.get();
    if (existing.exists) {
      const data = existing.data() || {};
      const sentAt = data.sentAt ? data.sentAt.toMillis() : 0;
      if (now - sentAt < 60000) {
        throw new HttpsError('resource-exhausted', 'Please wait before requesting another code.');
      }
    }

    await codesRef.set({
      email,
      userType,
      codeHash,
      attempts: 0,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(now + LOGIN_CODE_TTL_MS),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Queue the email in the existing mail collection.
    await admin.firestore().collection('mail').doc(`login-code-${email}-${now}`).set({
      to: email,
      message: {
        subject: 'Your BrisConnect+ sign-in code',
        html: getLoginEmailHtml(code, userType),
      },
      meta: {
        type: 'login_code',
        userType,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Login code queued', { email, userType });
    return { sent: true };
  },
);

exports.verifyEmailLoginCode = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
  },
  async (request) => {
    const email = String(request.data.email || '').trim().toLowerCase();
    const code = String(request.data.code || '').trim();
    const userType = String(request.data.userType || '').trim().toLowerCase();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (!code || code.length < 4) {
      throw new HttpsError('invalid-argument', 'A valid code is required.');
    }
    if (!['visitor', 'local'].includes(userType)) {
      throw new HttpsError('invalid-argument', 'userType must be visitor or local.');
    }

    const docId = loginCodeDocId(email);
    const codesRef = admin.firestore().collection('login_codes').doc(docId);
    const snap = await codesRef.get();

    if (!snap.exists) {
      throw new HttpsError('not-found', 'Code not found or expired.');
    }

    const data = snap.data() || {};
    const expiresAt = data.expiresAt ? data.expiresAt.toMillis() : 0;
    const now = Date.now();

    if (now > expiresAt) {
      await codesRef.delete();
      throw new HttpsError('deadline-exceeded', 'Code has expired. Please request a new one.');
    }

    if ((data.attempts || 0) >= LOGIN_CODE_MAX_ATTEMPTS) {
      await codesRef.delete();
      throw new HttpsError('resource-exhausted', 'Too many failed attempts. Please request a new code.');
    }

    const codeHash = hashCode(code);
    if (codeHash !== data.codeHash) {
      await codesRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError('permission-denied', 'Invalid code.');
    }

    // Code is valid. Ensure a Firebase Auth user exists for this email.
    let authUser;
    try {
      authUser = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        authUser = await admin.auth().createUser({ email });
      } else {
        throw error;
      }
    }

    // Ensure the Firestore profile document exists with basic defaults.
    const collection = userType === 'visitor' ? 'visitor_users' : 'local_users';
    const profileRef = admin.firestore().collection(collection).doc(email);
    const profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      const username = email.split('@')[0];
      const baseProfile = {
        email,
        username,
        role: userType,
        accountType: userType,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        active: true,
        notificationsEnabled: true,
        emailNotificationsEnabled: true,
      };
      if (userType === 'local') {
        baseProfile.approvalStatus = 'pending';
      }
      await profileRef.set(baseProfile);
    }

    // Clean up the used code.
    await codesRef.delete();

    // Create a custom token so the Flutter client can sign in.
    const token = await admin.auth().createCustomToken(authUser.uid, {
      email,
      userType,
    });

    logger.info('Login code verified', { email, userType });
    return { token };
  },
);

// ── Social sharing Open Graph proxy ─────────────────────────────────────────
exports.ogProxy = ogProxy;
