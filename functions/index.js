const admin = require('firebase-admin');
const crypto = require('node:crypto');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret, defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const twilio = require('twilio');

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
      const result = await client.messages.create({
        body: String(message),
        messagingServiceSid,
        to: String(to),
      });

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
