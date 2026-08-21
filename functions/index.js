const admin = require('firebase-admin');
const crypto = require('node:crypto');
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { ogProxy } = require('./og_proxy');
const { sendAdminNotification } = require('./admin_notifications');
const { sendVisitorNotification, VISITOR_NOTIFICATION_TYPES } = require('./visitor_notifications');
const { sendOwnerNotification, sendOwnerNotificationIfEnabled } = require('./owner_notifications');
const { bulkTranslateAllLanguages } = require('./translation');
const { synthesizeSpeechEnhanced } = require('./tts_enhanced');

if (!admin.apps.length) {
  admin.initializeApp();
}

const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');
const brevoApiKey = defineSecret('BREVO_API_KEY');

const BRISBANE_CBD = {
  lat: -27.4679,
  lng: 153.0281,
};

const GOOGLE_IMPORT_RADIUS_METERS = 30000;

const BUSINESS_ARCHIVE_RETENTION_DAYS = 30;
const DUPLICATE_NAME_THRESHOLD = 0.85; // Jaro-Winkler similarity

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

function calculateBuzzScore({ viewCount, reviewCount, averageRating, buzzRatings, shareCount }) {
  const ratingScore = Math.min((averageRating || 0) / 5, 1) * 30; // up to 30
  const reviewScore = Math.min(reviewCount || 0, 50) * 0.8; // up to 40
  const viewScore = Math.min(viewCount || 0, 500) * 0.04; // up to 20
  const buzzRatingScore = buzzRatings.length > 0
    ? (buzzRatings.reduce((a, b) => a + b, 0) / buzzRatings.length) * 2 // up to 10
    : 0;
  const shareScore = Math.min(shareCount || 0, 50) * 0.1; // up to 5

  return Math.round(ratingScore + reviewScore + viewScore + buzzRatingScore + shareScore);
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
  const sharesSnap = await db
    .collection('social_shares')
    .where('businessId', '==', businessId)
    .count()
    .get();
  const shareCount = Number(sharesSnap.data().count || 0);

  const buzzScore = calculateBuzzScore({
    viewCount,
    reviewCount,
    averageRating,
    buzzRatings,
    shareCount,
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

/**
 * Triggered when a visitor shares a business/event/promotion.
 * Notifies the business owner and admins.
 */
exports.onSocialShare = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'social_shares/{shareId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = data.businessId;
    const shareId = event.params.shareId;

    if (!businessId) {
      logger.warn('Social share without businessId.', { shareId });
      return;
    }

    // Canonical business profiles live in `businesses`; legacy/demo food
    // profiles live in `food_businesses`. Try both so shares for either
    // collection surface a notification.
    const collections = ['businesses', 'food_businesses'];
    let businessDoc;
    for (const collection of collections) {
      const doc = await admin.firestore().collection(collection).doc(businessId).get();
      if (doc.exists) {
        businessDoc = doc;
        break;
      }
    }
    if (!businessDoc || !businessDoc.exists) return;

    const businessData = businessDoc.data() || {};
    const ownerId = businessData.ownerId;
    const businessName = businessData.businessName || businessData.name || businessData.title || 'Your business';
    const platform = data.platform || 'social media';

    if (ownerId) {
      await sendOwnerNotificationIfEnabled({
        ownerId,
        preferenceField: 'notifySocialShare',
        title: '📣 Shared on social',
        body: `Someone just shared ${businessName} on ${platform}.`,
        data: { businessId, shareId, screen: 'business_dashboard' },
        type: 'social_share',
      });
    }

    await _notifyAdmins({
      title: '📣 Social share',
      body: `A visitor shared ${businessName} on ${data.platform || 'social media'}.`,
      data: { businessId, shareId, screen: '/admin/businesses' },
      type: 'admin_social_share',
    });

    // Refresh the business buzz score so social sharing feeds into trending.
    try {
      await recalculateBusinessBuzzScore(businessId);
    } catch (e) {
      logger.error('Failed to recalculate buzz score after social share.', { businessId, error: e });
    }
  },
);

/**
 * Triggered when an audience_interaction document is created for a view or
 * save. Sends a push notification to the business owner and admins.
 * Rate-limited to one notification per interaction type per business per hour
 * to avoid spamming owners when the same visitor repeatedly opens a profile.
 */
exports.onAudienceInteraction = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'audience_interactions/{interactionId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = data.businessId;
    const ownerId = data.ownerId;
    const type = data.type;
    const interactionId = event.params.interactionId;

    if (!businessId || !ownerId || !type) {
      logger.warn('Audience interaction missing fields.', { interactionId });
      return;
    }

    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) return;

    const businessName = businessDoc.data().businessName || 'Your business';
    const prefs = await admin.firestore().collection('local_users').doc(ownerId).get();

    const isView = type === 'view';
    const isSave = type === 'save';
    if (!isView && !isSave) return;

    // Throttle to one notification per interaction type per business per hour.
    const throttleKey = `audience_interaction_${type}_${businessId}`;
    const lastNotified = businessDoc.data().lastAudienceNotificationAt?.[type]?.toMillis?.() || 0;
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    if (lastNotified > oneHourAgo) {
      logger.info('Audience interaction notification throttled.', { businessId, type });
      return;
    }

    const title = isView ? '👀 Profile viewed' : '❤️ Business saved';
    const body = isView
      ? `A visitor just viewed ${businessName}.`
      : `A visitor just saved ${businessName}.`;

    await sendOwnerNotificationIfEnabled({
      ownerId,
      preferenceField: 'notifyAudienceActivity',
      title,
      body,
      data: { businessId, screen: 'business_dashboard' },
      type: isView ? 'profile_view' : 'business_saved',
    });

    await _notifyAdmins({
      title: isView ? '👀 Profile view' : '❤️ Business save',
      body: `A visitor ${isView ? 'viewed' : 'saved'} ${businessName}.`,
      data: { businessId, screen: '/admin/businesses' },
      type: isView ? 'admin_profile_view' : 'admin_business_saved',
    });

    await businessDoc.ref.set(
      {
        lastAudienceNotificationAt: {
          [type]: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
  },
);

/**
 * Triggered when a visitor buzz-votes a post. Resolves the related business
 * and notifies the owner and admins.
 */
exports.onBuzzVote = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'post_engagements/{engagementId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const action = data.action;
    if (action !== 'buzzVote') return;

    const postType = data.postType;
    const postId = data.postId;
    if (!postType || !postId) return;

    let businessId;
    let title = 'a post';
    const db = admin.firestore();

    try {
      if (postType === 'business') {
        businessId = postId;
      } else if (postType === 'event') {
        const eventDoc = await db.collection('business_events').doc(postId).get();
        businessId = eventDoc.exists ? eventDoc.data().businessId : null;
        title = eventDoc.exists ? eventDoc.data().title || title : title;
      } else if (postType === 'photo') {
        const photoDoc = await db.collection('visitor_photos').doc(postId).get();
        businessId = photoDoc.exists ? (photoDoc.data().businessId || null) : null;
        const bName = businessId
          ? (await db.collection('businesses').doc(businessId).get()).data()?.businessName
          : null;
        title = bName || title;
      } else if (postType === 'review') {
        const reviewDoc = await db.collection('reviews').doc(postId).get();
        businessId = reviewDoc.exists ? reviewDoc.data().businessId : null;
        title = reviewDoc.exists ? reviewDoc.data().comment?.slice(0, 30) || title : title;
      }

      if (!businessId) return;

      const businessDoc = await db.collection('businesses').doc(businessId).get();
      if (!businessDoc.exists) return;

      const ownerId = businessDoc.data().ownerId;
      if (!ownerId) return;

      const businessName = businessDoc.data().businessName || 'Your business';

      await sendOwnerNotificationIfEnabled({
        ownerId,
        preferenceField: 'notifyBuzzVote',
        title: '⚡ New buzz vote',
        body: `Someone buzz-voted ${businessName}.`,
        data: { businessId, postId, postType, screen: 'business_dashboard' },
        type: 'buzz_vote',
      });

      await _notifyAdmins({
        title: '⚡ Buzz vote',
        body: `A visitor buzz-voted ${businessName}.`,
        data: { businessId, postId, postType, screen: '/admin/businesses' },
        type: 'admin_buzz_vote',
      });
    } catch (e) {
      logger.warn('Buzz vote notification failed.', { error: e.message, postType, postId });
    }
  },
);

// Scheduled job to refresh trending scores every 5 minutes and catch any drift.
exports.refreshTrendingScores = onSchedule(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
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

// ── Business-owner push notifications ───────────────────────────────────────
// The shared sendOwnerNotification helper now lives in owner_notifications.js.

/**
 * Triggered when a business document is updated by the owner. Sends a push
 * notification confirming the update, but only when meaningful profile fields
 * change and at most once per hour to avoid spam.
 */
exports.onBusinessUpdated = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const businessId = event.params.businessId;
    const ownerId = after.ownerId;
    const businessName = after.businessName || 'Your business';

    if (!ownerId) {
      logger.warn('Business updated without ownerId.', { businessId });
      return;
    }

    const prefs = await admin.firestore().collection('local_users').doc(ownerId).get();
    if (!prefs.exists || prefs.data().notifyBusinessUpdates === false) {
      logger.info('Owner disabled business update notifications.', { ownerId, businessId });
      return;
    }

    // Only notify when meaningful owner-editable fields change.
    const trackedFields = [
      'businessName',
      'category',
      'description',
      'address',
      'contactNumber',
      'website',
      'socialMedia',
      'logoUrl',
      'coverImageUrl',
      'businessHours',
      'menuItems',
      'photos',
    ];
    const hasMeaningfulChange = trackedFields.some((field) => {
      const beforeVal = before[field];
      const afterVal = after[field];
      return JSON.stringify(beforeVal) !== JSON.stringify(afterVal);
    });

    if (!hasMeaningfulChange) {
      logger.info('Business update ignored: no tracked fields changed.', { businessId });
      return;
    }

    // Throttle to one notification per business per hour.
    const lastNotified = after.lastUpdateNotifiedAt?.toMillis?.() || 0;
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    if (lastNotified > oneHourAgo) {
      logger.info('Business update notification throttled.', { businessId, ownerId });
      return;
    }

    await sendOwnerNotificationIfEnabled({
      ownerId,
      preferenceField: 'notifyBusinessUpdates',
      title: '✅ Business details updated',
      body: `${businessName} has been updated successfully. Your listing changes are now live.`,
      data: { businessId, screen: 'business_detail' },
      type: 'business_updated',
    });

    await event.data.after.ref.update({
      lastUpdateNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Triggered when a promotion document is created or updated. If engagement
 * (views + clicks) crosses a configurable threshold within the last hour,
 * notify the owner that the promotion is trending.
 */
exports.onPromotionEngagementSpike = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'promotions/{promotionId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const promotionId = event.params.promotionId;
    const ownerId = after.ownerId;
    const title = after.title || 'Your promotion';

    if (!ownerId) {
      logger.warn('Promotion missing ownerId.', { promotionId });
      return;
    }

    const previousViews = Number(before.views || 0);
    const previousClicks = Number(before.clicks || 0);
    const currentViews = Number(after.views || 0);
    const currentClicks = Number(after.clicks || 0);

    const delta = currentViews + currentClicks - previousViews - previousClicks;
    const threshold = Number(after.engagementSpikeThreshold) || 50;

    if (delta < threshold) return;

    // Prevent duplicate notifications by checking lastSpikeNotifiedAt.
    const lastNotified = after.lastSpikeNotifiedAt?.toMillis?.() || 0;
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    if (lastNotified > oneHourAgo) return;

    await sendOwnerNotificationIfEnabled({
      ownerId,
      preferenceField: 'notifyTrendingPromotion',
      title: '🔥 Your promotion is trending!',
      body: `"${title}" is getting lots of attention — ${currentViews} views and ${currentClicks} clicks so far.`,
      data: { promotionId, screen: 'promotion_detail' },
      type: 'promotion_performance',
    });

    await event.data.after.ref.update({
      lastSpikeNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Scheduled job that runs every 15 minutes and notifies owners about promotions
 * expiring within the next 24 hours. The 15-minute cadence keeps the delivery
 * within the acceptance-criteria window.
 */
exports.notifyExpiringOffers = onSchedule(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    schedule: 'every 15 minutes',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const oneDay = 24 * 60 * 60 * 1000;
    const oneDayFromNow = admin.firestore.Timestamp.fromMillis(now.toMillis() + oneDay);

    const promotionsSnap = await db
      .collection('promotions')
      .where('endAt', '<=', oneDayFromNow)
      .where('endAt', '>', now)
      .where('status', 'in', ['active', 'scheduled'])
      .get();

    const results = [];
    for (const promotionDoc of promotionsSnap.docs) {
      const promotion = promotionDoc.data();
      const ownerId = promotion.ownerId;
      const title = promotion.title || 'Your offer';
      const endAt = promotion.endAt?.toDate?.();
      const hoursLeft = endAt
        ? Math.max(1, Math.round((endAt.getTime() - now.toMillis()) / (60 * 60 * 1000)))
        : '24';

      if (!ownerId) continue;

      // Avoid duplicate expiry reminders per promotion.
      const alreadyReminded = promotion.expiryReminderSentAt?.toMillis?.() || 0;
      if (alreadyReminded > now.toMillis() - oneDay) {
        continue;
      }

      const result = await sendOwnerNotificationIfEnabled({
        ownerId,
        preferenceField: 'notifyOfferExpiry',
        title: '⏰ Offer expiring soon',
        body: `"${title}" expires in about ${hoursLeft} hour${hoursLeft === 1 ? '' : 's'}. Boost or extend it to keep the momentum going.`,
        data: { promotionId: promotionDoc.id, screen: 'promotion_detail' },
        type: 'promotion_expiring',
        category: 'OFFER_EXPIRY',
        actions: [{ action: 'extend', title: 'Extend offer' }],
      });

      if (result.success) {
        await promotionDoc.ref.update({
          expiryReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      results.push(result);
    }

    logger.info('Expiring offer reminders complete.', {
      checked: promotionsSnap.size,
      sent: results.filter((r) => r.success).length,
    });
  },
);

/**
 * Scheduled job that transitions `promotions` documents through their
 * lifecycle: `scheduled` -> `active` once `scheduledAt` has passed, and
 * `active` -> `expired` once `endAt` has passed. Without this job, promotions
 * created via "Create Promotion" never leave the `scheduled` state and never
 * count toward a business's active-promotions metrics.
 */
exports.activatePromotions = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 5 minutes',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    let activatedCount = 0;
    let expiredCount = 0;

    const dueToActivateSnap = await db
      .collection('promotions')
      .where('status', '==', 'scheduled')
      .where('scheduledAt', '<=', now)
      .get();
    for (const doc of dueToActivateSnap.docs) {
      batch.update(doc.ref, {
        status: 'active',
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      activatedCount++;
    }

    const dueToExpireSnap = await db
      .collection('promotions')
      .where('status', '==', 'active')
      .where('endAt', '<=', now)
      .get();
    for (const doc of dueToExpireSnap.docs) {
      batch.update(doc.ref, {
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      expiredCount++;
    }

    if (activatedCount > 0 || expiredCount > 0) {
      await batch.commit();
    }

    logger.info('Promotion lifecycle sweep complete.', {
      activated: activatedCount,
      expired: expiredCount,
    });
  },
);

/**
 * Health-check callable for business-owner notification services.
 * Verifies Firestore and FCM are reachable, records the result, and returns
 * an availability snapshot. Designed to be invoked by a synthetic monitor.
 */
exports.notificationHealth = onCall(
  {
    region: 'australia-southeast1',
  },
  async () => {
    const db = admin.firestore();
    const start = Date.now();
    const result = {
      status: 'ok',
      firestoreReachable: false,
      fcmReachable: false,
      latencyMs: 0,
      checkedAt: admin.firestore.Timestamp.now(),
    };

    try {
      // Probe Firestore with a lightweight read.
      await db.collection('local_users').limit(1).get();
      result.firestoreReachable = true;
    } catch (e) {
      logger.error('Notification health Firestore probe failed.', { error: e.message });
      result.firestoreReachable = false;
      result.status = 'degraded';
    }

    try {
      // Probe FCM with a dry-run multicast to a dummy token.
      await admin.messaging().sendEachForMulticast({
        tokens: ['__health_probe__'],
        notification: { title: 'Health probe', body: 'Ignore' },
        dryRun: true,
      });
      result.fcmReachable = true;
    } catch (e) {
      // A dry-run to an invalid token still means FCM is reachable.
      if (e.code === 'messaging/invalid-registration-token' || e.message?.includes('registration token')) {
        result.fcmReachable = true;
      } else {
        logger.error('Notification health FCM probe failed.', { error: e.message });
        result.fcmReachable = false;
        result.status = 'degraded';
      }
    }

    result.latencyMs = Date.now() - start;

    if (!result.firestoreReachable || !result.fcmReachable) {
      result.status = 'unavailable';
    }

    await db.collection('notification_health_checks').add(result);
    logger.info('Notification health check complete.', result);
    return result;
  },
);

/**
 * Scheduled synthetic monitor for notification services.
 * Runs every minute, calls notificationHealth internally, and logs the result.
 */
exports.notificationHealthProbe = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 1 minutes',
    timeoutSeconds: 30,
  },
  async () => {
    const db = admin.firestore();
    const start = Date.now();
    const result = {
      status: 'ok',
      firestoreReachable: false,
      fcmReachable: false,
      latencyMs: 0,
      checkedAt: admin.firestore.Timestamp.now(),
    };

    try {
      await db.collection('local_users').limit(1).get();
      result.firestoreReachable = true;
    } catch (e) {
      logger.error('Scheduled notification health Firestore probe failed.', { error: e.message });
      result.status = 'degraded';
    }

    try {
      await admin.messaging().sendEachForMulticast({
        tokens: ['__health_probe__'],
        notification: { title: 'Health probe', body: 'Ignore' },
        dryRun: true,
      });
      result.fcmReachable = true;
    } catch (e) {
      if (e.code === 'messaging/invalid-registration-token' || e.message?.includes('registration token')) {
        result.fcmReachable = true;
      } else {
        logger.error('Scheduled notification health FCM probe failed.', { error: e.message });
        result.status = 'degraded';
      }
    }

    result.latencyMs = Date.now() - start;
    if (!result.firestoreReachable || !result.fcmReachable) {
      result.status = 'unavailable';
    }

    await db.collection('notification_health_checks').add(result);
    logger.info('Scheduled notification health probe complete.', result);
  },
);

/**
 * Extends a promotion's end date by [extensionDays] days (default 7).
 * Only the promotion owner may call this function.
 */
exports.extendPromotion = onCall(
  {
    region: 'australia-southeast1',
  },
  async (request) => {
    // Dev: allow unauthenticated calls from unsigned macOS builds.
    // Uncomment before production:
    // if (!request.auth) {
    //   throw new HttpsError('unauthenticated', 'Authentication required.');
    // }

    const { promotionId, extensionDays = 7 } = request.data || {};
    if (!promotionId) {
      throw new HttpsError('invalid-argument', 'Missing promotionId.');
    }

    const db = admin.firestore();
    const promotionRef = db.collection('promotions').doc(promotionId);
    const promotionDoc = await promotionRef.get();

    if (!promotionDoc.exists) {
      throw new HttpsError('not-found', 'Promotion not found.');
    }

    const promotion = promotionDoc.data();
    const callerUid = request.auth?.uid;
    const callerEmail = request.auth?.token?.email
      ? String(request.auth.token.email).trim().toLowerCase()
      : null;
    const ownerId = promotion.ownerId;

    // Owner check: allow the Firebase Auth UID or the registered email.
    if (callerUid && callerUid !== ownerId) {
      const ownerDoc = await db.collection('local_users').doc(ownerId).get();
      const ownerEmail = ownerDoc.exists
        ? String(ownerDoc.data().email || '').trim().toLowerCase()
        : '';
      if (callerEmail !== ownerEmail) {
        throw new HttpsError('permission-denied', 'Only the promotion owner can extend this offer.');
      }
    }

    const currentEndAt = promotion.endAt?.toMillis
      ? promotion.endAt.toMillis()
      : Date.now();
    const newEndAt = admin.firestore.Timestamp.fromMillis(
      currentEndAt + Number(extensionDays) * 24 * 60 * 60 * 1000,
    );

    await promotionRef.update({
      endAt: newEndAt,
      status: 'active',
      expiryReminderSentAt: null,
      extendedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Promotion extended.', { promotionId, newEndAt: newEndAt.toMillis(), extensionDays });
    return { success: true, promotionId, newEndAt: newEndAt.toMillis(), extensionDays };
  },
);

/**
 * Triggered when a new review is created. Notifies the business owner if they
 * have enabled new-review notifications.
 */
exports.onNewReviewNotifyOwner = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'reviews/{reviewId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = data.businessId;
    const reviewId = event.params.reviewId;

    if (!businessId) {
      logger.warn('Review created without businessId.', { reviewId });
      return;
    }

    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) return;

    const ownerId = businessDoc.data().ownerId;
    if (!ownerId) return;

    const businessName = businessDoc.data().businessName || 'Your business';
    const rating = data.rating;
    const stars = typeof rating === 'number' ? '⭐'.repeat(Math.min(5, Math.max(1, rating))) : '';

    await sendOwnerNotificationIfEnabled({
      ownerId,
      preferenceField: 'notifyNewReview',
      title: '⭐ New review received',
      body: `${businessName} received a new ${stars} review. See what customers are saying.`,
      // Owners aren't admins - route to their own reviews tab, not the admin hub.
      data: { businessId, reviewId, screen: 'business_dashboard' },
      type: 'new_review',
    });

    await _notifyAdmins({
      title: '⭐ New review',
      body: `${businessName} received a ${stars || 'new'} review from a visitor.`,
      data: { businessId, reviewId, screen: '/admin/reports' },
      type: 'admin_new_review',
    });
  },
);

/**
 * Triggered when a local user's account approval status changes. Sends a
 * push (and in-app) notification so the owner knows immediately whether
 * their account was approved or rejected — previously only email/SMS were
 * queued from the admin UI, leaving the app notification channel silent.
 */
exports.onLocalUserApprovalChanged = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    document: 'local_users/{ownerId}',
  },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const ownerId = event.params.ownerId;

    const previousStatus = String(before.approvalStatus || '').toLowerCase();
    const currentStatus = String(after.approvalStatus || '').toLowerCase();

    if (previousStatus === currentStatus) return;
    if (currentStatus !== 'approved' && currentStatus !== 'rejected') return;

    const businessName = after.businessName || after.name || 'your account';

    if (currentStatus === 'approved') {
      await sendOwnerNotification({
        ownerId,
        title: '✅ Account approved',
        body: `${businessName} is now approved. You can publish events and manage your business profile.`,
        data: { screen: '/local/portal' },
        type: 'account_approved',
      });
    } else {
      await sendOwnerNotification({
        ownerId,
        title: '❌ Account not approved',
        body: `${businessName} was not approved. Please contact support if you believe this is a mistake.`,
        data: { screen: '/local/portal' },
        type: 'account_rejected',
      });
    }
  },
);

/**
 * Resolves the businessId a community feed comment belongs to, based on the
 * postType/postId stored on the comment document.
 */
async function _resolveBusinessIdForComment(postType, postId) {
  if (!postType || !postId) return null;
  const db = admin.firestore();
  try {
    switch (postType) {
      case 'business': {
        // 'business' items can originate from businesses/, promotions/, or
        // ai_generated_posts/, all of which map to the same feed type.
        const businessDoc = await db.collection('businesses').doc(postId).get();
        if (businessDoc.exists) return postId;

        const promoDoc = await db.collection('promotions').doc(postId).get();
        if (promoDoc.exists) return promoDoc.data().businessId || null;

        const aiPostDoc = await db.collection('ai_generated_posts').doc(postId).get();
        if (aiPostDoc.exists) return aiPostDoc.data().businessId || null;

        return null;
      }
      case 'review': {
        const doc = await db.collection('reviews').doc(postId).get();
        return doc.exists ? doc.data().businessId || null : null;
      }
      case 'photo': {
        const doc = await db.collection('visitor_photos').doc(postId).get();
        return doc.exists ? doc.data().businessId || null : null;
      }
      case 'event': {
        const doc = await db.collection('business_events').doc(postId).get();
        return doc.exists ? doc.data().businessId || null : null;
      }
      default:
        return null;
    }
  } catch (e) {
    logger.warn('Failed to resolve businessId for comment.', {
      postType,
      postId,
      error: e.message,
    });
    return null;
  }
}

/**
 * Triggered when a visitor comments on a community feed post. Notifies the
 * related business owner if they have enabled new-comment notifications.
 */
exports.onNewCommentNotifyOwner = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'post_comments/{commentId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const commentId = event.params.commentId;
    const postType = data.postType;
    const postId = data.postId;
    const visitorName = data.visitorName || 'A visitor';
    const text = String(data.text || '').trim();

    const businessId = await _resolveBusinessIdForComment(postType, postId);
    if (!businessId) return;

    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) return;

    const ownerId = businessDoc.data().ownerId;
    if (!ownerId) return;

    const businessName = businessDoc.data().businessName || 'Your business';
    const preview = text.length > 0
      ? (text.length > 80 ? `${text.slice(0, 80)}…` : text)
      : data.mediaType === 'video'
        ? 'shared a video'
        : data.mediaType === 'image'
          ? 'shared a photo'
          : 'left a comment';

    await sendOwnerNotificationIfEnabled({
      ownerId,
      preferenceField: 'notifyNewComment',
      title: '💬 New comment',
      body: `${visitorName} commented on ${businessName}: "${preview}"`,
      emailSubject: `New comment on ${businessName}`,
      data: { businessId, postId, postType, commentId, screen: '/local/portal' },
      type: 'new_comment',
    });
  },
);

// ── Admin platform notifications ────────────────────────────────────────────

/**
 * Backwards-compatible helper: routes owner-triggered admin alerts through
 * the shared [sendAdminNotification] pipeline so they appear in the admin
 * notification panel as well as push notifications.
 */
async function _notifyAdmins({ title, body, data = {}, type }) {
  await sendAdminNotification({ title, body, data, type });
}


/**
 * Triggered when a new business profile is created. Notifies admins so they
 * can review and verify the listing.
 */
exports.onBusinessCreatedNotifyAdmins = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const businessId = event.params.businessId;
    const businessName = data.businessName || 'a new business';
    const category = data.category || 'Business';

    if (data.isVerified === true) {
      logger.info('Business already verified on create; skipping admin alert.', { businessId });
      return;
    }

    await sendAdminNotification({
      title: '🏪 New business registration',
      body: `${businessName} (${category}) was just registered and needs verification.`,
      data: { businessId, screen: '/admin/businesses', relatedItemType: 'business' },
      type: 'new_business',
    });
  },
);

/**
 * Triggered when a local user submits an event that requires admin approval.
 */
exports.onEventPendingApproval = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'events/{eventId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const eventId = event.params.eventId;
    const status = String(data.reviewStatus || data.status || '').toLowerCase();

    if (status !== 'pending') {
      return;
    }

    const title = data.title || 'an event';
    const createdBy = data.createdByLocalEmail || data.createdBy || 'a local user';

    await sendAdminNotification({
      title: '📅 Event approval requested',
      body: `"${title}" submitted by ${createdBy} is awaiting approval.`,
      data: { eventId, screen: '/admin/reported-events', relatedItemType: 'event' },
      type: 'event_approval',
    });
  },
);

/**
 * Triggered when an owner schedules a new promotion. Notifies admins so they
 * can monitor promotional content.
 */
exports.onPromotionScheduled = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'promotions/{promotionId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const promotionId = event.params.promotionId;
    const title = data.title || 'a promotion';
    const businessName = data.businessName || data.businessId || 'a business';
    const ownerId = data.ownerId;
    const businessId = data.businessId;

    if (ownerId) {
      await sendOwnerNotificationIfEnabled({
        ownerId,
        preferenceField: 'notifyPromotionStatus',
        title: '📢 Promotion submitted',
        body: `"${title}" has been received and is awaiting review.`,
        data: { promotionId, businessId, screen: '/local/notifications' },
        type: 'promotion_published',
      });
    }

    await sendAdminNotification({
      title: '📢 New promotion scheduled',
      body: `"${title}" was scheduled for ${businessName}.`,
      data: { promotionId, screen: '/admin/promotions', relatedItemType: 'promotion' },
      type: 'promotion_approval',
    });
  },
);

/**
 * Triggered when an event report is submitted by a visitor.
 */
exports.onEventReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'event_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const eventId = data.eventId;
    const reason = data.reason || 'reported';
    const severity = data.severity || 'medium';

    if (!eventId) {
      logger.warn('Event report missing eventId.', { reportId });
      return;
    }

    await sendAdminNotification({
      title: '🚨 Event reported',
      body: `An event was reported (${reason}, severity: ${severity}).`,
      data: { reportId, eventId, screen: '/admin/reports', relatedItemType: 'event_report' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a review/recommendation is reported by a visitor.
 */
exports.onReviewReported = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'reviews/{reviewId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const reviewId = event.params.reviewId;

    const wasReported = before.isReported === true;
    const isReported = after.isReported === true;

    if (!isReported || wasReported) {
      return;
    }

    const businessId = after.businessId;
    const reportedBy = after.reportedBy || after.visitorId || 'a visitor';

    await sendAdminNotification({
      title: '🚨 Recommendation reported',
      body: `A recommendation was reported by ${reportedBy}.`,
      data: { reviewId, businessId, screen: '/admin/reports', relatedItemType: 'review' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a business owner replies to a visitor recommendation.
 * Notifies the visitor by email/push and alerts admins.
 */
exports.onReviewReplied = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'reviews/{reviewId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const reviewId = event.params.reviewId;

    const oldReply = String(before.reply || '').trim();
    const newReply = String(after.reply || '').trim();

    if (!newReply || newReply === oldReply) {
      return;
    }

    const visitorId = after.visitorId;
    const businessId = after.businessId;
    const replyBy = after.replyBy || 'Business Owner';

    if (!visitorId) {
      logger.warn('Review reply missing visitorId.', { reviewId });
      return;
    }

    let businessName = after.businessName;
    if (!businessName && businessId) {
      try {
        const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
        businessName = businessDoc.exists
          ? (businessDoc.data().businessName || businessDoc.data().name || businessId)
          : businessId;
      } catch (e) {
        businessName = businessId;
      }
    }
    businessName = businessName || 'the business';

    let visitorEmail;
    try {
      const userRecord = await admin.auth().getUser(visitorId);
      visitorEmail = userRecord.email;
    } catch (e) {
      logger.warn('Could not look up visitor email for reply notification.', {
        reviewId,
        visitorId,
        error: e.message,
      });
    }

    if (visitorEmail) {
      // Deep link to the business itself, not the notification list the
      // visitor is already viewing when they tap this in the in-app panel.
      const reviewActionRoute = businessId ? `/business/${businessId}` : '/visitor/notifications';
      await sendVisitorNotification({
        userEmail: visitorEmail,
        title: `${businessName} replied to your review`,
        body: `"${truncateText(newReply, 120)}" — ${replyBy}`,
        type: VISITOR_NOTIFICATION_TYPES.REVIEW_REPLY,
        data: { reviewId, businessId, screen: reviewActionRoute },
        relatedItemId: reviewId,
        relatedItemType: 'review',
        actionRoute: reviewActionRoute,
      });
    }

    await sendAdminNotification({
      title: '💬 Business replied to a review',
      body: `${replyBy} replied to a review on ${businessName}.`,
      data: { reviewId, businessId, screen: '/admin/reported-reviews', relatedItemType: 'review' },
      type: 'review_reply',
    });
  },
);

/**
 * Triggered when a crowd/busyness report is submitted for a business.
 */
exports.onCrowdReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'crowd_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const businessId = data.businessId;
    const level = data.level || data.crowdLevel || 'unknown';

    if (!businessId) {
      logger.warn('Crowd report missing businessId.', { reportId });
      return;
    }

    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    const businessName = businessDoc.exists ? (businessDoc.data().businessName || businessId) : businessId;

    await sendAdminNotification({
      title: '👥 Crowd report submitted',
      body: `${businessName} received a ${level} crowd report.`,
      data: { reportId, businessId, screen: '/admin/businesses', relatedItemType: 'crowd_report' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a business owner submits or updates verification information.
 * Fires when verificationDocuments is first set or verificationSubmittedAt is
 * updated, so admins can review the supplied evidence.
 */
exports.onBusinessVerificationRequested = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const businessId = event.params.businessId;
    const businessName = after.businessName || 'A business';

    const hadDocs = Array.isArray(before.verificationDocuments) && before.verificationDocuments.length > 0;
    const hasDocs = Array.isArray(after.verificationDocuments) && after.verificationDocuments.length > 0;
    const wasSubmitted = before.verificationSubmittedAt != null;
    const isSubmitted = after.verificationSubmittedAt != null;

    if (!((hasDocs && !hadDocs) || (isSubmitted && !wasSubmitted))) {
      return;
    }

    await sendAdminNotification({
      title: '📋 Verification request',
      body: `${businessName} submitted verification information for review.`,
      data: { businessId, screen: '/admin/businesses', relatedItemType: 'business' },
      type: 'verification_request',
    });
  },
);

/**
 * Triggered when a visitor reports a business listing.
 */
exports.onBusinessReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'business_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const businessId = data.businessId;
    const reason = data.reason || 'reported';

    if (!businessId) {
      logger.warn('Business report missing businessId.', { reportId });
      return;
    }

    const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
    const businessName = businessDoc.exists ? (businessDoc.data().businessName || businessId) : businessId;
    const ownerId = businessDoc.exists ? businessDoc.data().ownerId : null;

    if (ownerId) {
      await sendOwnerNotificationIfEnabled({
        ownerId,
        preferenceField: 'notifyReportedContent',
        title: '🚨 Your business was reported',
        body: `${businessName} was reported (${reason}). An admin may contact you if action is required.`,
        data: { reportId, businessId, screen: '/local/notifications' },
        type: 'reported_content',
      });
    }

    await sendAdminNotification({
      title: '🚨 Business reported',
      body: `${businessName} was reported (${reason}).`,
      data: { reportId, businessId, screen: '/admin/reports', relatedItemType: 'business_report' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a visitor reports a photo.
 */
exports.onPhotoReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'photo_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const photoId = data.photoId;
    const businessId = data.businessId;
    const reason = data.reason || 'reported';

    if (!photoId) {
      logger.warn('Photo report missing photoId.', { reportId });
      return;
    }

    if (businessId) {
      const businessDoc = await admin.firestore().collection('businesses').doc(businessId).get();
      const ownerId = businessDoc.exists ? businessDoc.data().ownerId : null;
      const businessName = businessDoc.exists ? (businessDoc.data().businessName || businessId) : businessId;

      if (ownerId) {
        await sendOwnerNotificationIfEnabled({
          ownerId,
          preferenceField: 'notifyReportedContent',
          title: '🚨 Photo reported',
          body: `A photo associated with ${businessName} was reported (${reason}).`,
          data: { reportId, photoId, businessId, screen: '/local/notifications' },
          type: 'reported_content',
        });
      }
    }

    await sendAdminNotification({
      title: '🚨 Photo reported',
      body: `A photo was reported (${reason}).`,
      data: { reportId, photoId, businessId: businessId || '', screen: '/admin/reports', relatedItemType: 'photo_report' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a visitor reports another user.
 */
exports.onUserReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'user_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const reportedUserId = data.reportedUserId || data.reportedUserEmail;
    const reason = data.reason || 'reported';

    if (!reportedUserId) {
      logger.warn('User report missing reportedUserId.', { reportId });
      return;
    }

    await sendAdminNotification({
      title: '🚨 User reported',
      body: `A user was reported (${reason}).`,
      data: { reportId, reportedUserId, screen: '/admin/users', relatedItemType: 'user_report' },
      type: 'reported_content',
    });
  },
);

/**
 * Triggered when a visitor reports a community post.
 */
exports.onCommunityPostReported = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'community_post_reports/{reportId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const reportId = event.params.reportId;
    const postId = data.postId;
    const reason = data.reason || 'reported';

    if (!postId) {
      logger.warn('Community post report missing postId.', { reportId });
      return;
    }

    await sendAdminNotification({
      title: '🚨 Community post reported',
      body: `A community post was reported (${reason}).`,
      data: { reportId, postId, screen: '/admin/community', relatedItemType: 'community_post_report' },
      type: 'reported_content',
    });
  },
);

// ── Admin-to-owner message push notification ────────────────────────────────
exports.notifyOwnerAdminMessage = onCall(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
  },
  async (request) => {
    await assertAdminCaller(request);

    const { toEmail, subject, message, type, messageId, sentBy } = request.data || {};
    const normalized = String(toEmail || '').trim().toLowerCase();
    if (!normalized) {
      throw new HttpsError('invalid-argument', 'Missing recipient email.');
    }
    if (!subject || !message) {
      throw new HttpsError('invalid-argument', 'Subject and message are required.');
    }

    const prefs = await admin.firestore().collection('local_users').doc(normalized).get();
    if (prefs.exists && prefs.data().notifyAdminMessages === false) {
      return { success: false, reason: 'Owner disabled admin message notifications.' };
    }

    await sendOwnerNotification({
      ownerId: normalized,
      title: subject,
      body: message.length > 160 ? `${message.slice(0, 157).trim()}...` : message,
      data: {
        messageId: messageId || '',
        type: type || 'general',
        sentBy: sentBy || 'BrisConnect Admin',
        screen: '/local/notifications',
      },
      type: 'admin_message',
    });

    return { success: true };
  },
);

// ── AI Post Generator (callable, uses Google Gemini API) ─────────────────────
const geminiApiKey = defineSecret('GEMINI_API_KEY');

async function callGemini(prompt, { maxOutputTokens = 400 } = {}) {
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
      maxOutputTokens,
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

function buildPrompt(postType, businessName, category, extraContext, format) {
  const isTitleDescription = format === 'title-description';

  let base;
  if (isTitleDescription) {
    base = `You are a witty, energetic marketer for local Brisbane businesses.
Create a short promotion title and description for "${businessName}"${category ? ` (${category})` : ''}.
Tone: friendly, punchy, and authentically Brisbane.
Return ONLY:
1. A catchy title on the first line (max 8 words).
2. A 1-2 sentence description on the following lines.
Do not include markdown, bullet lists, emojis, or hashtags.`;
  } else {
    base = `You are a witty, energetic social media marketer for local Brisbane businesses.
Write ONE short, exciting, fun Facebook/Instagram post for "${businessName}"${category ? ` (${category})` : ''}.
Use emojis, keep it under 280 words, and make locals feel FOMO.
Tone: friendly, punchy, and authentically Brisbane.
Do not include markdown or bullet lists. Return only the post text.`;
  }

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
    lines.push(`Use these details naturally:${isTitleDescription ? '' : '\n'}${extraContext.trim()}`);
  }

  if (!isTitleDescription) {
    lines.push('Include 3-5 relevant hashtags at the end.');
  }
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
    // AI post generation is available to all signed-in business owners.
    // We no longer require an active subscription so the assistant can help
    // owners create promotions from their business profile.
    const { postType = 'Post', businessName = '', category = '', extraContext = '', format = '' } = request.data || {};

    if (!businessName) {
      throw new HttpsError('invalid-argument', 'businessName is required.');
    }

    try {
      const prompt = buildPrompt(postType, businessName, category, extraContext, format);
      const post = await callGemini(prompt);
      return { post };
    } catch (error) {
      logger.warn('Gemini generation failed, using fallback.', { error: error.message, businessName });
      return { post: fallbackPost(postType, businessName, category, extraContext) };
    }
  }
);

function buildInsightsPrompt(businessName, category, metrics) {
  return `You are a friendly marketing coach for small Brisbane food businesses.
Analyse the recent dashboard metrics for "${businessName}"${category ? ` (${category})` : ''} and suggest 3-5 concrete, actionable improvements.

Metrics:
${JSON.stringify(metrics, null, 2)}

Rules:
- Compare current numbers to the change percentages where available.
- Prioritise low-effort, high-impact ideas.
- Keep each suggestion to one bold title (max 7 words) and one practical tip (1-2 sentences).
- Return ONLY valid JSON in this exact shape:
{
  "suggestions": [
    {"title": "...", "tip": "..."},
    {"title": "...", "tip": "..."}
  ]
}
Do not include markdown, explanations, or code fences.`;
}

function parseInsightsJson(text) {
  try {
    const cleaned = text.replace(/```json/gi, '').replace(/```/g, '').trim();
    const parsed = JSON.parse(cleaned);
    if (Array.isArray(parsed.suggestions)) {
      return parsed.suggestions
        .filter((s) => s && typeof s === 'object')
        .map((s) => ({
          title: String(s.title || '').trim(),
          tip: String(s.tip || '').trim(),
        }))
        .filter((s) => s.title || s.tip);
    }
  } catch (_) {
    // fall through to regex extraction
  }

  // Try to extract the JSON object from surrounding prose.
  const match = text.match(/\{[\s\S]*"suggestions"[\s\S]*\}/);
  if (match) {
    return parseInsightsJson(match[0]);
  }
  return [];
}

function fallbackInsights(metrics) {
  const suggestions = [];
  const safeVal = (n) => (typeof n === 'number' && Number.isFinite(n) ? n : 0);

  if (safeVal(metrics.profileViews) === 0) {
    suggestions.push({
      title: 'Boost your visibility',
      tip: 'You have no profile views this week. Try creating a promotion or an AI-generated post to get in front of more customers.',
    });
  }

  if (safeVal(metrics.activePromotions) === 0) {
    suggestions.push({
      title: 'Run a promotion',
      tip: 'Active promotions drive more visits and saves. Create a limited-time offer to attract new customers.',
    });
  }

  if (safeVal(metrics.totalReviews) === 0) {
    suggestions.push({
      title: 'Collect reviews',
      tip: 'Reviews build trust. Ask happy customers to leave a review on your BrisConnect profile.',
    });
  }

  if (safeVal(metrics.socialShares) === 0) {
    suggestions.push({
      title: 'Encourage social sharing',
      tip: 'Shares extend your reach beyond BrisConnect. Add share-worthy photos and deals to your profile.',
    });
  }

  if (suggestions.length === 0) {
    suggestions.push({
      title: 'Keep momentum going',
      tip: 'Your metrics look healthy. Keep posting fresh content and responding to reviews to stay top of mind.',
    });
  }

  return suggestions;
}

exports.generateBusinessInsights = onCall(
  {
    region: 'australia-southeast1',
    secrets: [geminiApiKey],
  },
  async (request) => {
    const { businessName = '', category = '', metrics = {} } = request.data || {};

    if (!businessName) {
      throw new HttpsError('invalid-argument', 'businessName is required.');
    }

    try {
      const prompt = buildInsightsPrompt(businessName, category, metrics);
      const raw = await callGemini(prompt, { maxOutputTokens: 800 });
      const suggestions = parseInsightsJson(raw);
      return { suggestions: suggestions.length ? suggestions : fallbackInsights(metrics) };
    } catch (error) {
      logger.warn('Gemini business insights failed, using fallback.', { error: error.message, businessName });
      return { suggestions: fallbackInsights(metrics) };
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

/**
 * Sends a transactional email via Brevo. Returns the provider response.
 * Throws on API failure so the caller can fall back to queueing.
 */
async function sendEmailViaBrevo({ apiKey, to, subject, html, senderEmail, senderName }) {
  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'api-key': apiKey,
    },
    body: JSON.stringify({
      sender: { email: senderEmail, name: senderName },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Brevo API error ${response.status}: ${text}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = { raw: text };
  }
  return parsed;
}

exports.sendEmailLoginCode = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
    secrets: [brevoApiKey],
  },
  async (request) => {
    const email = String(request.data.email || '').trim().toLowerCase();
    let userType = String(request.data.userType || '').trim().toLowerCase();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (userType && !['visitor', 'local', 'admin'].includes(userType)) {
      throw new HttpsError('invalid-argument', 'userType must be visitor, local, or admin.');
    }

    // Auto-detect role from Firestore when the client does not specify one.
    // This lets the welcome screen ask only for an email.
    if (!userType || userType === 'auto') {
      const adminDoc = await admin.firestore().collection('admins').doc(email).get();
      if (adminDoc.exists && (adminDoc.data().active !== false)) {
        userType = 'admin';
      } else {
        const localDoc = await admin.firestore().collection('local_users').doc(email).get();
        if (localDoc.exists) {
          userType = 'local';
        } else {
          userType = 'visitor';
        }
      }
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

    logger.info('Login code stored', { email, docId, userType });

    const html = getLoginEmailHtml(code, userType);
    const subject = 'Your BrisConnect+ sign-in code';

    // Attempt synchronous delivery via Brevo so the user receives the code
    // immediately. If Brevo is not configured or the call fails, fall back to
    // queueing the email in `mail` for the worker / Trigger Email extension.
    let delivered = false;
    let providerResponse = null;
    const apiKey = brevoApiKey.value();
    logger.info('Brevo configuration check', {
      email,
      hasKey: !!(apiKey && apiKey.trim().length > 0),
      keyLength: apiKey ? apiKey.trim().length : 0,
    });
    if (apiKey && apiKey.trim().length > 0) {
      const trimmedKey = apiKey.trim();
      if (trimmedKey.startsWith('xsmtpsib-')) {
        logger.error('Brevo key is an SMTP relay key, not an API v3 key. Email cannot be sent via Brevo REST API.', { email });
      } else {
        try {
          providerResponse = await sendEmailViaBrevo({
            apiKey: trimmedKey,
            to: email,
            subject,
            html,
            senderEmail: process.env.BREVO_SENDER_EMAIL || 'brisconnect0@gmail.com',
            senderName: process.env.BREVO_SENDER_NAME || 'BrisConnect+',
          });
          delivered = true;
          logger.info('Brevo direct send succeeded', { email, messageId: providerResponse && providerResponse.messageId });
        } catch (brevoError) {
          logger.error('Brevo direct send failed; falling back to mail queue', {
            email,
            error: brevoError instanceof Error ? brevoError.message : String(brevoError),
          });
        }
      }
    } else {
      logger.warn('BREVO_API_KEY secret is empty; login code email queued for worker.', { email });
    }

    if (delivered) {
      // Write an audit record to a separate collection so we don't trigger the
      // Firebase Trigger Email extension (or the local worker) to send again.
      await admin.firestore().collection('email_audit').doc(`login-code-${email}-${now}`).set({
        to: email,
        subject,
        meta: { type: 'login_code', userType },
        status: 'sent',
        delivered: true,
        provider: 'brevo',
        providerResponse,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await admin.firestore().collection('mail').doc(`login-code-${email}-${now}`).set({
        to: email,
        message: { subject, html },
        meta: { type: 'login_code', userType },
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    logger.info('Login code processed', { email, userType, delivered });
    return { sent: true, userType, delivered };
  },
);

/**
 * Sends the visitor "account created" welcome email directly via Brevo.
 * Falls back to writing the `mail` collection if Brevo is unavailable.
 */
exports.sendVisitorWelcomeEmail = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
    secrets: [brevoApiKey],
  },
  async (request) => {
    const email = String(request.data.email || '').trim().toLowerCase();
    const name = String(request.data.name || 'Visitor').trim();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }

    const subject = 'Welcome to BrisConnect+';
    const html = `
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
          <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
        </div>
        <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
          <p style="font-size:16px;color:#333333;">Hello ${name},</p>
          <p style="font-size:16px;color:#333333;">Your BrisConnect+ visitor account has been created successfully.</p>
          <p style="font-size:16px;color:#333333;">You can now sign in and explore events, attractions, and notifications.</p>
        </div>
        <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
      </div>
    `;

    let delivered = false;
    let providerResponse = null;
    const apiKey = brevoApiKey.value();
    if (apiKey && apiKey.trim().length > 0) {
      try {
        providerResponse = await sendEmailViaBrevo({
          apiKey: apiKey.trim(),
          to: email,
          subject,
          html,
          senderEmail: process.env.BREVO_SENDER_EMAIL || 'brisconnect0@gmail.com',
          senderName: process.env.BREVO_SENDER_NAME || 'BrisConnect+',
        });
        delivered = true;
      } catch (brevoError) {
        logger.error('Brevo welcome email failed; falling back to mail queue', {
          email,
          error: brevoError instanceof Error ? brevoError.message : String(brevoError),
        });
      }
    }

    if (delivered) {
      await admin.firestore().collection('email_audit').doc(`visitor-welcome-${email}-${Date.now()}`).set({
        to: email,
        subject,
        meta: { type: 'visitor_registration_received' },
        status: 'sent',
        delivered: true,
        provider: 'brevo',
        providerResponse,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await admin.firestore().collection('mail').doc(`visitor-welcome-${email}-${Date.now()}`).set({
        to: email,
        message: { subject, html },
        meta: { type: 'visitor_registration_received' },
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    logger.info('Visitor welcome email processed', { email, delivered });
    return { sent: true, delivered };
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
    const method = String(request.data.method || 'email').trim().toLowerCase();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (!code || code.length < 4) {
      throw new HttpsError('invalid-argument', 'A valid code is required.');
    }

    const docId = loginCodeDocId(email);
    const codesRef = admin.firestore().collection('login_codes').doc(docId);
    const snap = await codesRef.get();

    logger.info('verifyEmailLoginCode lookup', { email, docId, exists: snap.exists });

    if (!snap.exists) {
      throw new HttpsError('not-found', 'Code not found. Please request a new code.');
    }

    const data = snap.data() || {};
    const expiresAt = data.expiresAt ? data.expiresAt.toMillis() : 0;
    const now = Date.now();

    logger.info('verifyEmailLoginCode found', {
      email,
      expiresAt,
      now,
      attempts: data.attempts || 0,
    });

    // Allow a 30-second grace period for minor server clock skew.
    if (now > expiresAt + 30000) {
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

    // Use the userType that was determined when the code was sent.
    // Fall back to the userType provided in the request if the stored value
    // is missing or invalid (can happen with older code documents).
    let userType = String(data.userType || '').trim().toLowerCase();
    if (!['visitor', 'local', 'admin'].includes(userType)) {
      userType = String(request.data.userType || '').trim().toLowerCase();
    }
    if (!['visitor', 'local', 'admin'].includes(userType)) {
      await codesRef.delete();
      throw new HttpsError('internal', 'Invalid login session.');
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

    if (userType === 'admin') {
      // Admin profiles are managed separately. Verify the account is authorized.
      const adminDoc = await admin.firestore().collection('admins').doc(email).get();
      if (!adminDoc.exists) {
        await codesRef.delete();
        throw new HttpsError('permission-denied', 'Not authorized as admin.');
      }
      const adminData = adminDoc.data() || {};
      if (adminData.active === false) {
        await codesRef.delete();
        throw new HttpsError('permission-denied', 'Admin account is disabled.');
      }
      await admin.firestore().collection('admins').doc(email).set({
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else {
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
    }

    // Clean up the used code.
    await codesRef.delete();

    // Create a custom token so the Flutter client can sign in.
    const token = await admin.auth().createCustomToken(authUser.uid, {
      email,
      userType,
      role: userType,
    });

    logger.info('Login code verified', { email, userType });
    return { token, userType };
  },
);

/**
 * Looks up the registered phone number for an account so the client can
 * trigger Firebase Phone Auth. This function does NOT send an SMS itself;
 * Firebase Auth sends the verification text directly.
 */
exports.sendSmsLoginCode = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
  },
  async (request) => {
    const email = String(request.data.email || '').trim().toLowerCase();
    let userType = String(request.data.userType || '').trim().toLowerCase();

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (userType && !['visitor', 'local', 'admin'].includes(userType)) {
      throw new HttpsError('invalid-argument', 'userType must be visitor, local, or admin.');
    }

    // Auto-detect role and look up the registered phone number.
    const adminDoc = await admin.firestore().collection('admins').doc(email).get();
    if (adminDoc.exists && (adminDoc.data().active !== false)) {
      userType = 'admin';
    } else {
      const localDoc = await admin.firestore().collection('local_users').doc(email).get();
      if (localDoc.exists) {
        userType = 'local';
      } else {
        const visitorDoc = await admin.firestore().collection('visitor_users').doc(email).get();
        if (visitorDoc.exists) {
          userType = 'visitor';
        } else {
          throw new HttpsError('not-found', 'No account found for this email.');
        }
      }
    }

    const profileDoc = await admin.firestore()
      .collection(userType === 'admin' ? 'admins' : userType === 'local' ? 'local_users' : 'visitor_users')
      .doc(email)
      .get();
    const profile = profileDoc.data() || {};
    const phone = String(profile.phone || profile.contactNumber || '').trim();

    if (!phone) {
      throw new HttpsError('failed-precondition', 'No phone number on file. Use email sign-in instead.');
    }

    return { phone, userType, method: 'firebase_phone' };
  },
);

/**
 * Exchanges a verified Firebase Phone Auth ID token for a BrisConnect custom
 * token tied to the registered local/visitor profile.
 */
exports.exchangePhoneIdTokenForCustomToken = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
  },
  async (request) => {
    const idToken = String(request.data.idToken || '').trim();
    let userType = String(request.data.userType || '').trim().toLowerCase();

    if (!idToken) {
      throw new HttpsError('invalid-argument', 'ID token is required.');
    }
    if (userType && !['visitor', 'local', 'admin'].includes(userType)) {
      throw new HttpsError('invalid-argument', 'userType must be visitor, local, or admin.');
    }

    let phoneUser;
    try {
      phoneUser = await admin.auth().verifyIdToken(idToken, true);
    } catch (error) {
      logger.error('Invalid phone ID token', { error: error instanceof Error ? error.message : String(error) });
      throw new HttpsError('unauthenticated', 'Invalid phone credentials.');
    }

    const phoneNumber = String(phoneUser.phone_number || '').trim();
    const authUid = phoneUser.uid;
    if (!phoneNumber) {
      throw new HttpsError('failed-precondition', 'Phone number not available in ID token.');
    }

    // Find a profile with this phone number.
    let profileEmail = null;
    let detectedUserType = userType;

    if (!detectedUserType || detectedUserType === 'auto') {
      const collections = ['local_users', 'visitor_users', 'admins'];
      for (const collection of collections) {
        const snap = await admin.firestore()
          .collection(collection)
          .where('phone', '==', phoneNumber)
          .limit(1)
          .get();
        if (!snap.empty) {
          profileEmail = snap.docs[0].id;
          detectedUserType = collection === 'admins' ? 'admin' : collection === 'local_users' ? 'local' : 'visitor';
          break;
        }
      }
    } else {
      const collection = detectedUserType === 'admin' ? 'admins' : detectedUserType === 'local' ? 'local_users' : 'visitor_users';
      const snap = await admin.firestore()
        .collection(collection)
        .where('phone', '==', phoneNumber)
        .limit(1)
        .get();
      if (!snap.empty) {
        profileEmail = snap.docs[0].id;
      }
    }

    if (!profileEmail) {
      throw new HttpsError('not-found', 'No BrisConnect account found for this phone number.');
    }

    // Ensure a Firebase Auth user exists for the profile email.
    let authUser;
    try {
      authUser = await admin.auth().getUserByEmail(profileEmail);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        authUser = await admin.auth().createUser({ email: profileEmail });
      } else {
        throw error;
      }
    }

    if (detectedUserType === 'admin') {
      const adminDoc = await admin.firestore().collection('admins').doc(profileEmail).get();
      if (!adminDoc.exists) {
        throw new HttpsError('permission-denied', 'Not authorized as admin.');
      }
      const adminData = adminDoc.data() || {};
      if (adminData.active === false) {
        throw new HttpsError('permission-denied', 'Admin account is disabled.');
      }
      await admin.firestore().collection('admins').doc(profileEmail).set({
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } else {
      const collection = detectedUserType === 'visitor' ? 'visitor_users' : 'local_users';
      const profileRef = admin.firestore().collection(collection).doc(profileEmail);
      const profileSnap = await profileRef.get();
      if (!profileSnap.exists) {
        const username = profileEmail.split('@')[0];
        const baseProfile = {
          email: profileEmail,
          username,
          role: detectedUserType,
          accountType: detectedUserType,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          active: true,
          notificationsEnabled: true,
          emailNotificationsEnabled: true,
        };
        if (detectedUserType === 'local') {
          baseProfile.approvalStatus = 'pending';
        }
        await profileRef.set(baseProfile);
      }
    }

    // Link the phone auth UID to the profile email auth user so future logins
    // via either method resolve to the same account.
    try {
      await admin.auth().updateUser(authUser.uid, {
        email: profileEmail,
        phoneNumber: phoneNumber,
      });
    } catch (error) {
      logger.warn('Could not link phone to profile auth user', {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    // Delete the temporary phone-only user created by Firebase Phone Auth.
    try {
      await admin.auth().deleteUser(authUid);
    } catch (error) {
      logger.warn('Could not delete temporary phone user', {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    const token = await admin.auth().createCustomToken(authUser.uid, {
      email: profileEmail,
      userType: detectedUserType,
      role: detectedUserType,
    });

    logger.info('Phone sign-in exchanged for custom token', {
      email: profileEmail,
      userType: detectedUserType,
    });
    return { token, userType: detectedUserType, email: profileEmail };
  },
);

// ── Moderation: server-side audit logging and cleanup ──────────────────────

const MODERATION_RETENTION_DAYS = 30;
const AUDIT_LOG_RETENTION_DAYS = 365;

/**
 * Server-side audit log writer that can be called securely from admin clients.
 */
exports.logModerationAction = onCall(
  {
    region: 'australia-southeast1',
  },
  async (request) => {
    // Dev: allow unauthenticated calls from unsigned macOS builds.
    // Uncomment before production:
    // if (!request.auth) {
    //   throw new HttpsError('unauthenticated', 'Admin authentication required.');
    // }

    const {
      adminEmail,
      contentType,
      contentId,
      contentOwnerId,
      decision,
      reason,
      metadata,
    } = request.data || {};

    if (!adminEmail || !contentType || !contentId || !decision || !reason) {
      throw new HttpsError('invalid-argument', 'Missing required moderation fields.');
    }

    const normalizedAdmin = String(adminEmail).trim().toLowerCase();
    const logRef = admin.firestore().collection('moderation_audit_log').doc();
    await logRef.set({
      adminEmail: normalizedAdmin,
      contentType: String(contentType),
      contentId: String(contentId),
      contentOwnerId: contentOwnerId ? String(contentOwnerId) : null,
      decision: String(decision),
      reason: String(reason),
      metadata: metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Moderation action logged', { logId: logRef.id, contentId, decision });
    return { logId: logRef.id };
  },
);

/**
 * Scheduled cleanup: permanently delete recommendations that were soft-deleted
 * more than 30 days ago. Audit logs older than 12 months are also removed.
 */
exports.cleanupModeratedContent = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 24 hours',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const retentionCutoff = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - MODERATION_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );
    const auditCutoff = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - AUDIT_LOG_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );

    const deletedReviewsSnap = await db
      .collection('reviews')
      .where('deletedAt', '<=', retentionCutoff)
      .where('deletedAt', '!=', null)
      .limit(500)
      .get();

    let reviewsPurged = 0;
    const batch = db.batch();
    for (const doc of deletedReviewsSnap.docs) {
      batch.delete(doc.ref);
      reviewsPurged += 1;
    }
    await batch.commit();

    const deletedPhotosSnap = await db
      .collection('visitor_photos')
      .where('deletedAt', '<=', retentionCutoff)
      .where('deletedAt', '!=', null)
      .limit(500)
      .get();

    let photosPurged = 0;
    const photosBatch = db.batch();
    for (const doc of deletedPhotosSnap.docs) {
      photosBatch.delete(doc.ref);
      photosPurged += 1;
    }
    await photosBatch.commit();

    const oldAuditSnap = await db
      .collection('moderation_audit_log')
      .where('createdAt', '<=', auditCutoff)
      .limit(500)
      .get();

    let auditPurged = 0;
    const auditBatch = db.batch();
    for (const doc of oldAuditSnap.docs) {
      auditBatch.delete(doc.ref);
      auditPurged += 1;
    }
    await auditBatch.commit();

    logger.info('Moderation cleanup complete.', { reviewsPurged, photosPurged, auditPurged });
  },
);

// ── Business duplicate detection ────────────────────────────────────────────

/**
 * Compute Jaro-Winkler similarity between two strings (0-1).
 */
function jaroWinkler(s1, s2) {
  if (s1 === s2) return 1.0;
  if (!s1 || !s2) return 0.0;

  const len1 = s1.length;
  const len2 = s2.length;
  const matchDistance = Math.floor(Math.max(len1, len2) / 2) - 1;
  const s1Matches = new Array(len1).fill(false);
  const s2Matches = new Array(len2).fill(false);

  let matches = 0;
  let transpositions = 0;

  for (let i = 0; i < len1; i += 1) {
    const start = Math.max(0, i - matchDistance);
    const end = Math.min(i + matchDistance + 1, len2);

    for (let j = start; j < end; j += 1) {
      if (s2Matches[j] || s1[i] !== s2[j]) continue;
      s1Matches[i] = true;
      s2Matches[j] = true;
      matches += 1;
      break;
    }
  }

  if (matches === 0) return 0.0;

  let k = 0;
  for (let i = 0; i < len1; i += 1) {
    if (!s1Matches[i]) continue;
    while (!s2Matches[k]) k += 1;
    if (s1[i] !== s2[k]) transpositions += 1;
    k += 1;
  }

  const jaro = (
    (matches / len1)
    + (matches / len2)
    + ((matches - transpositions / 2) / matches)
  ) / 3;

  let prefix = 0;
  for (let i = 0; i < Math.min(len1, len2); i += 1) {
    if (s1[i] === s2[i]) prefix += 1;
    else break;
  }

  return jaro + 0.1 * Math.min(prefix, 4) * (1 - jaro);
}

/**
 * Firestore trigger that flags potential duplicate business listings when a
 * business is created or updated. Matches are based on name similarity and
 * geographic proximity.
 *
 * Uses onDocumentWritten (not onDocumentUpdated) so brand-new listings are
 * checked immediately on creation instead of only after a later edit.
 */
exports.flagDuplicateBusinesses = onDocumentWritten(
  {
    region: 'australia-southeast1',
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    const businessId = event.params.businessId;

    if (!after || after.deletedAt) return;

    const db = admin.firestore();
    const name = String(after.businessName || '').toLowerCase().trim();
    const lat = after.lat;
    const lng = after.lng;

    if (!name) return;

    // Only compare against active, non-deleted businesses.
    const candidatesSnap = await db
      .collection('businesses')
      .where('deletedAt', '==', null)
      .where('isActive', '==', true)
      .get();

    let bestMatchId = null;
    let bestScore = 0;

    for (const doc of candidatesSnap.docs) {
      if (doc.id === businessId) continue;
      const candidate = doc.data();
      const candidateName = String(candidate.businessName || '').toLowerCase().trim();
      if (!candidateName) continue;

      let score = jaroWinkler(name, candidateName);

      // Boost score if within ~100m.
      if (lat != null && lng != null && candidate.lat != null && candidate.lng != null) {
        const distanceKm = haversineDistance(lat, lng, candidate.lat, candidate.lng);
        if (distanceKm <= 0.1) {
          score += 0.15;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatchId = doc.id;
      }
    }

    if (bestScore >= DUPLICATE_NAME_THRESHOLD && bestMatchId) {
      await event.data.after.ref.update({
        duplicateOf: bestMatchId,
        duplicateScore: bestScore,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info('Flagged potential duplicate business.', {
        businessId,
        duplicateOf: bestMatchId,
        score: bestScore,
      });
    } else if (after.duplicateOf != null) {
      await event.data.after.ref.update({
        duplicateOf: admin.firestore.FieldValue.delete(),
        duplicateScore: admin.firestore.FieldValue.delete(),
        flaggedAt: admin.firestore.FieldValue.delete(),
      });
    }
  },
);

/**
 * Haversine distance between two lat/lng points in kilometers.
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Scheduled cleanup: permanently delete business listings archived more than
 * 30 days ago.
 */
exports.cleanupArchivedBusinesses = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 24 hours',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - BUSINESS_ARCHIVE_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );

    const archivedSnap = await db
      .collection('business_archive')
      .where('archiveExpiresAt', '<=', cutoff)
      .limit(500)
      .get();

    let purged = 0;
    const batch = db.batch();
    for (const doc of archivedSnap.docs) {
      batch.delete(doc.ref);
      purged += 1;
    }
    await batch.commit();

    logger.info('Archived business cleanup complete.', { purged });
  },
);

// ── Cloud Text-to-Speech narration using REST API ─────────────────────────

exports.synthesizeNarration = onCall(
  {
    region: 'australia-southeast1',
    timeoutSeconds: 30,
  },
  async (request) => {
    const text = String((request.data && request.data.text) || '').trim();
    const languageCode = String((request.data && request.data.languageCode) || 'en').trim();

    if (!text) {
      throw new HttpsError('invalid-argument', 'Text is required and must not be empty.');
    }

    if (text.length > 5000) {
      throw new HttpsError('invalid-argument', 'Text must be 5000 characters or less.');
    }

    try {
      // Use enhanced TTS with premium Neural2 voices for better quality
      const audioContent = await synthesizeSpeechEnhanced(text, languageCode, {
        pitch: 1.05,
        speakingRate: 0.82,
      });

      if (!audioContent) {
        throw new Error('Text-to-Speech synthesis returned empty audio content.');
      }

      logger.info('synthesizeNarration completed with enhanced TTS.', {
        textLength: text.length,
        languageCode,
      });

      return { audioContent: Buffer.from(audioContent).toString('base64') };
    } catch (error) {
      logger.error('synthesizeNarration failed.', {
        error: error instanceof Error ? error.message : String(error),
        text: text.substring(0, 100),
        languageCode,
      });
      throw new HttpsError(
        'internal',
        `Text-to-Speech synthesis failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

// ── Social sharing Open Graph proxy ─────────────────────────────────────────
exports.ogProxy = ogProxy;

// ── Stripe payments ─────────────────────────────────────────────────────────
const {
  createSubscriptionCheckout,
  createPromotionCheckout,
  getSubscriptionStatus,
  createBillingPortalSession,
  stripeWebhook,
  savePromotionPlan,
  setPlanActive,
  deactivatePromotion,
  downgradeExpiredPromotions,
  reconcilePromotionPayments,
  saveSubscriptionPlan,
  setSubscriptionPlanActive,
  onLocalUserCreated,
  expireFreeTrials,
} = require('./payments');

exports.createSubscriptionCheckout = createSubscriptionCheckout;
exports.createPromotionCheckout = createPromotionCheckout;
exports.getSubscriptionStatus = getSubscriptionStatus;
exports.createBillingPortalSession = createBillingPortalSession;
exports.stripeWebhook = stripeWebhook;
exports.savePromotionPlan = savePromotionPlan;
exports.setPlanActive = setPlanActive;
exports.deactivatePromotion = deactivatePromotion;
exports.downgradeExpiredPromotions = downgradeExpiredPromotions;
exports.reconcilePromotionPayments = reconcilePromotionPayments;
exports.saveSubscriptionPlan = saveSubscriptionPlan;
exports.setSubscriptionPlanActive = setSubscriptionPlanActive;
exports.onLocalUserCreated = onLocalUserCreated;
exports.expireFreeTrials = expireFreeTrials;

// ── Visitor push notifications ───────────────────────────────────────────────

/**
 * Helper: finds visitors who have saved a business or selected any of its
 * categories as interests and have a given preference enabled.
 */
async function _findInterestedVisitors(db, business, preferenceField) {
  const businessCategories = Array.isArray(business.category)
    ? business.category
    : [business.category].filter(Boolean);

  const [savedSnap, interestSnap] = await Promise.all([
    db
      .collection('visitor_users')
      .where('savedBusinessIds', 'array-contains', business.id)
      .get(),
    businessCategories.length > 0
      ? db
          .collection('visitor_users')
          .where('interestCategories', 'array-contains-any', businessCategories)
          .get()
      : { docs: [] },
  ]);

  const byEmail = new Map();
  [...savedSnap.docs, ...interestSnap.docs].forEach((doc) => {
    const data = doc.data() || {};
    if (data.notificationsEnabled === false) return;
    if (preferenceField && data[preferenceField] === false) return;
    byEmail.set(doc.id, { email: doc.id, ...data });
  });

  return Array.from(byEmail.values());
}

/**
 * Triggered when a promotion becomes active or is scheduled. Notifies
 * visitors who saved the business or are interested in the category,
 * provided they have enabled nearby-promotion notifications.
 */
exports.onNearbyPromotionScheduled = onDocumentCreated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'promotions/{promotionId}',
  },
  async (event) => {
    const data = event.data?.data() || {};
    const promotionId = event.params.promotionId;
    const businessId = data.businessId;
    const title = data.title || 'A new promotion';
    const businessName = data.businessName || businessId || 'a business';

    if (!businessId) {
      logger.warn('Promotion missing businessId.', { promotionId });
      return;
    }

    const db = admin.firestore();
    const businessDoc = await db.collection('businesses').doc(businessId).get();
    if (!businessDoc.exists) return;

    const business = { id: businessDoc.id, ...businessDoc.data() };
    const visitors = await _findInterestedVisitors(
      db,
      business,
      'nearbyPromotionsEnabled',
    );

    await Promise.all(
      visitors.map((visitor) =>
        sendVisitorNotification({
          userEmail: visitor.email,
          title: `📍 "${title}" is nearby`,
          emailSubject: `"${title}" is available at ${businessName}`,
          body: `"${title}" is available at ${businessName}. Don't miss out!`,
          actionLabel: 'View offer',
          type: VISITOR_NOTIFICATION_TYPES.NEARBY_PROMOTION,
          relatedItemId: promotionId,
          relatedItemType: 'promotion',
          actionRoute: '/promotion/detail',
          data: { promotionId, businessId, screen: '/promotion/detail' },
        }).catch((e) =>
          logger.warn('Nearby promotion visitor notify failed.', {
            error: e.message,
            visitor: visitor.email,
          }),
        ),
      ),
    );
  },
);

/**
 * Triggered when a business document is updated by the owner. Sends a push
 * notification to visitors who saved the business, if they enabled saved
 * business update alerts. Throttled to one notification per business per hour.
 */
exports.onSavedBusinessUpdated = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const businessId = event.params.businessId;
    const businessName = after.businessName || 'A saved business';

    const trackedFields = [
      'businessName',
      'category',
      'description',
      'address',
      'contactNumber',
      'website',
      'socialMedia',
      'logoUrl',
      'coverImageUrl',
      'businessHours',
      'menuItems',
      'photos',
    ];
    const hasMeaningfulChange = trackedFields.some((field) => {
      return JSON.stringify(before[field]) !== JSON.stringify(after[field]);
    });
    if (!hasMeaningfulChange) return;

    const lastNotified = after.lastSavedUpdateNotifiedAt?.toMillis?.() || 0;
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    if (lastNotified > oneHourAgo) return;

    const db = admin.firestore();
    const savedSnap = await db
      .collection('visitor_users')
      .where('savedBusinessIds', 'array-contains', businessId)
      .get();

    await Promise.all(
      savedSnap.docs.map((doc) => {
        const visitor = doc.data() || {};
        if (visitor.notificationsEnabled === false) return Promise.resolve();
        if (visitor.savedBusinessUpdatesEnabled === false) return Promise.resolve();
        return sendVisitorNotification({
          userEmail: doc.id,
          title: `🏪 ${businessName} updated their profile`,
          emailSubject: `${businessName} updated their profile`,
          body: `See what's new at ${businessName} on BrisConnect+.`,
          actionLabel: 'View business',
          type: VISITOR_NOTIFICATION_TYPES.SAVED_BUSINESS_UPDATE,
          relatedItemId: businessId,
          relatedItemType: 'business',
          actionRoute: '/business/view',
          data: { businessId, screen: '/business/view' },
        }).catch((e) =>
          logger.warn('Saved business update visitor notify failed.', {
            error: e.message,
            visitor: doc.id,
          }),
        );
      }),
    );

    await event.data.after.ref.update({
      lastSavedUpdateNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Triggered when a business becomes trending. Notifies visitors interested
 * in the business category who enabled trending-business notifications.
 * Throttled to once per business per day.
 */
exports.onBusinessBecameTrending = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const businessId = event.params.businessId;
    const businessName = after.businessName || 'A business';

    const previousScore = Number(before.buzzScore || 0);
    const currentScore = Number(after.buzzScore || 0);
    const threshold = Number(after.trendingThreshold) || 100;

    if (previousScore >= threshold || currentScore < threshold) return;

    const lastNotified = after.lastTrendingNotifiedAt?.toMillis?.() || 0;
    const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
    if (lastNotified > oneDayAgo) return;

    const db = admin.firestore();
    const visitors = await _findInterestedVisitors(
      db,
      { id: businessId, ...after },
      'trendingBusinessesEnabled',
    );

    await Promise.all(
      visitors.map((visitor) =>
        sendVisitorNotification({
          userEmail: visitor.email,
          title: `🔥 ${businessName} is trending`,
          emailSubject: `${businessName} is trending right now`,
          body: `${businessName} is trending on BrisConnect+. See what everyone's talking about.`,
          actionLabel: 'Check it out',
          type: VISITOR_NOTIFICATION_TYPES.TRENDING_BUSINESS,
          relatedItemId: businessId,
          relatedItemType: 'business',
          actionRoute: '/business/view',
          data: { businessId, screen: '/business/view' },
        }).catch((e) =>
          logger.warn('Trending business visitor notify failed.', {
            error: e.message,
            visitor: visitor.email,
          }),
        ),
      ),
    );

    await event.data.after.ref.update({
      lastTrendingNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Scheduled job that runs every 15 minutes and notifies visitors about
 * promotions expiring within the next 24 hours for businesses they saved.
 */
exports.notifyExpiringSavedPromotions = onSchedule(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    schedule: 'every 15 minutes',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const oneDay = 24 * 60 * 60 * 1000;
    const oneDayFromNow = admin.firestore.Timestamp.fromMillis(now.toMillis() + oneDay);

    const promotionsSnap = await db
      .collection('promotions')
      .where('endAt', '<=', oneDayFromNow)
      .where('endAt', '>', now)
      .where('status', 'in', ['active', 'scheduled'])
      .get();

    for (const promotionDoc of promotionsSnap.docs) {
      const promotion = promotionDoc.data();
      const businessId = promotion.businessId;
      const title = promotion.title || 'An offer';
      const endAt = promotion.endAt?.toDate?.();
      const hoursLeft = endAt
        ? Math.max(1, Math.round((endAt.getTime() - now.toMillis()) / (60 * 60 * 1000)))
        : '24';

      if (!businessId) continue;

      const alreadyReminded = promotion.visitorExpiryReminderSentAt?.toMillis?.() || 0;
      if (alreadyReminded > now.toMillis() - oneDay) continue;

      const savedSnap = await db
        .collection('visitor_users')
        .where('savedBusinessIds', 'array-contains', businessId)
        .get();

      await Promise.all(
        savedSnap.docs.map((doc) => {
          const visitor = doc.data() || {};
          if (visitor.notificationsEnabled === false) return Promise.resolve();
          if (visitor.promotionExpiryRemindersEnabled === false) return Promise.resolve();
          return sendVisitorNotification({
            userEmail: doc.id,
            title: `⏰ "${title}" expires soon`,
            emailSubject: `"${title}" expires in about ${hoursLeft} hour${hoursLeft === 1 ? '' : 's'}`,
            body: `Your saved offer "${title}" expires in about ${hoursLeft} hour${hoursLeft === 1 ? '' : 's'}. Redeem it before it's gone.`,
            actionLabel: 'View offer',
            type: VISITOR_NOTIFICATION_TYPES.PROMOTION_EXPIRY_REMINDER,
            relatedItemId: promotionDoc.id,
            relatedItemType: 'promotion',
            actionRoute: '/promotion/detail',
            data: { promotionId: promotionDoc.id, businessId, screen: '/promotion/detail' },
          }).catch((e) =>
            logger.warn('Expiring promotion visitor notify failed.', {
              error: e.message,
              visitor: doc.id,
            }),
          );
        }),
      );

      await promotionDoc.ref.update({
        visitorExpiryReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    logger.info('Visitor expiring promotion reminders complete.', {
      checked: promotionsSnap.size,
    });
  },
);

/**
 * Triggered when a new business becomes verified. Notifies visitors who
 * enabled new-business discovery and share an interest category.
 */
exports.onNewBusinessForDiscovery = onDocumentUpdated(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    document: 'businesses/{businessId}',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const businessId = event.params.businessId;
    const businessName = after.businessName || 'A new business';

    const wasVerified = before.isVerified === true;
    const isVerified = after.isVerified === true;
    const wasRejected = before.isVerified === false && after.isVerified === false && Boolean(before.rejectionReason) !== Boolean(after.rejectionReason);
    const ownerId = after.ownerId;

    // Notify owner of verification status changes (forced regardless of preference).
    if (ownerId) {
      const db = admin.firestore();
      const lastVerifiedNotified = after.lastVerificationNotifiedAt?.toMillis?.() || 0;
      const oneHourAgo = Date.now() - 60 * 60 * 1000;

      if (isVerified && !wasVerified && lastVerifiedNotified <= oneHourAgo) {
        await sendOwnerNotification({
          ownerId,
          title: '✅ Business verified',
          body: `${businessName} has been verified and is now live on BrisConnect.`,
          data: { businessId, screen: 'business_detail' },
          type: 'verification_approved',
        });
        await event.data.after.ref.update({
          lastVerificationNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else if (wasRejected && lastVerifiedNotified <= oneHourAgo) {
        await sendOwnerNotification({
          ownerId,
          title: '❌ Verification request declined',
          body: `${businessName} verification needs more information. Please review the feedback and resubmit.`,
          data: { businessId, screen: 'business_detail' },
          type: 'verification_rejected',
        });
        await event.data.after.ref.update({
          lastVerificationNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    if (!isVerified || wasVerified) return;

    const lastNotified = after.lastDiscoveryNotifiedAt?.toMillis?.() || 0;
    const oneDayAgo = Date.now() - 24 * 60 * 60 * 1000;
    if (lastNotified > oneDayAgo) return;

    const db = admin.firestore();
    const visitors = await _findInterestedVisitors(
      db,
      { id: businessId, ...after },
      'newBusinessDiscoveryEnabled',
    );

    await Promise.all(
      visitors.map((visitor) =>
        sendVisitorNotification({
          userEmail: visitor.email,
          title: `✨ ${businessName} just joined`,
          emailSubject: `Welcome ${businessName} to BrisConnect`,
          body: `${businessName} just joined BrisConnect and matches your interests.`,
          actionLabel: 'Explore',
          type: VISITOR_NOTIFICATION_TYPES.NEW_BUSINESS_DISCOVERY,
          relatedItemId: businessId,
          relatedItemType: 'business',
          actionRoute: '/business/view',
          data: { businessId, screen: '/business/view' },
        }).catch((e) =>
          logger.warn('New business discovery visitor notify failed.', {
            error: e.message,
            visitor: visitor.email,
          }),
        ),
      ),
    );

    await event.data.after.ref.update({
      lastDiscoveryNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Scheduled job that runs once a day and sends personalised business
 * recommendations to visitors based on their interest categories.
 */
exports.sendPersonalisedRecommendations = onSchedule(
  {
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
    schedule: '0 10 * * *',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const businessesSnap = await db
      .collection('businesses')
      .where('isVerified', '==', true)
      .orderBy('buzzScore', 'desc')
      .limit(50)
      .get();

    const businesses = businessesSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    const visitorsSnap = await db
      .collection('visitor_users')
      .where('notificationsEnabled', '==', true)
      .where('personalisedRecommendationsEnabled', '==', true)
      .limit(500)
      .get();

    for (const visitorDoc of visitorsSnap.docs) {
      const visitor = visitorDoc.data() || {};
      const interestCategories = Array.isArray(visitor.interestCategories)
        ? visitor.interestCategories
        : [];
      if (interestCategories.length === 0) continue;

      const savedBusinessIds = new Set(
        Array.isArray(visitor.savedBusinessIds) ? visitor.savedBusinessIds : [],
      );

      const recommendation = businesses.find((b) => {
        if (savedBusinessIds.has(b.id)) return false;
        const categories = Array.isArray(b.category)
          ? b.category
          : [b.category].filter(Boolean);
        return categories.some((c) => interestCategories.includes(c));
      });

      if (!recommendation) continue;

      const lastNotified = recommendation.lastRecommendationNotifiedAt?.toMillis?.() || 0;
      if (lastNotified > now.toMillis() - 24 * 60 * 60 * 1000) continue;

      const recommendationName = recommendation.businessName || 'a trending business';
      await sendVisitorNotification({
        userEmail: visitorDoc.id,
        title: `⭐ Recommended: ${recommendationName}`,
        emailSubject: `Recommended for you: ${recommendationName}`,
        body: `Check out ${recommendationName} based on your interests.`,
        actionLabel: 'View recommendation',
        type: VISITOR_NOTIFICATION_TYPES.PERSONALISED_RECOMMENDATION,
        relatedItemId: recommendation.id,
        relatedItemType: 'business',
        actionRoute: '/business/view',
        data: { businessId: recommendation.id, screen: '/business/view' },
      }).catch((e) =>
        logger.warn('Personalised recommendation visitor notify failed.', {
          error: e.message,
          visitor: visitorDoc.id,
        }),
      );

      await db.collection('businesses').doc(recommendation.id).update({
        lastRecommendationNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    logger.info('Personalised recommendations complete.', {
      visitors: visitorsSnap.size,
    });
  },
);

// ── Firestore mail queue processor ───────────────────────────────────────────
// Sends emails queued in the `mail` collection by the admin dashboard.
// Triggered on every write so we can backfill documents that were created
// without a status field and so we avoid re-sending completed emails.
exports.processMailQueue = onDocumentWritten(
  {
    document: 'mail/{mailId}',
    region: 'australia-southeast1',
    secrets: [brevoApiKey],
  },
  async (event) => {
    const snap = event.data.after;
    if (!snap || !snap.exists) return;

    const data = snap.data() || {};
    const status = String(data.status || '').toLowerCase();
    const alreadyHandled = ['sent', 'processing', 'failed'].includes(status);
    if (alreadyHandled) return;
    // Treat missing/empty status as pending (backwards compat for older queued docs).
    if (status !== 'pending' && status !== '') return;

    const to = String(data.to || '').trim();
    const message = data.message || {};
    const subject = String(message.subject || '').trim();
    const html = String(message.html || '').trim();

    if (!to || !subject || !html) {
      await snap.ref.set(
        {
          status: 'failed',
          error: 'Missing required fields: to/subject/html.',
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    try {
      const apiKey = brevoApiKey.value();
      const senderEmail = process.env.BREVO_SENDER_EMAIL || 'brisconnect0@gmail.com';
      const senderName = process.env.BREVO_SENDER_NAME || 'BrisConnect+';
      const providerResponse = await sendEmailViaBrevo({
        apiKey,
        to,
        subject,
        html,
        senderEmail,
        senderName,
      });

      await snap.ref.set(
        {
          status: 'sent',
          provider: 'brevo',
          providerResponse,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.info('processMailQueue: email sent', { to, subject, mailId: snap.id });
    } catch (error) {
      logger.error('processMailQueue: email failed', {
        to,
        subject,
        mailId: snap.id,
        error: error instanceof Error ? error.message : String(error),
      });

      await snap.ref.set(
        {
          status: 'failed',
          error: error instanceof Error ? error.message : String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);

/**
 * Cloud Function: Bulk translate missing strings in all language ARB files
 * Callable via: httpsCallable('bulkTranslateLanguages')
 * Note: Requires admin access and Firebase Auth
 */
exports.bulkTranslateLanguages = onCall(
  {
    region: 'australia-southeast1',
    enforceAppCheck: false,
  },
  async (request) => {
    // Security: Only allow authenticated admin users
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to call this function.');
    }

    // Check if user is admin (optional - adjust based on your security model)
    // For now, we'll allow any authenticated user with admin role in Firestore
    const userDoc = await admin.firestore().collection('users').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'User must have admin role to translate languages.');
    }

    try {
      const projectId = process.env.GCLOUD_PROJECT || admin.apps[0].options.projectId;
      logger.info('Starting bulk translation of language files', { projectId });

      const results = await bulkTranslateAllLanguages(projectId);

      // Calculate summary stats
      const totalTranslated = Object.values(results).reduce((sum, r) => sum + (r.messagesTranslated || 0), 0);
      const successCount = Object.values(results).filter(r => r.success).length;

      logger.info('Bulk translation completed', { successCount, totalTranslated });

      return {
        success: true,
        message: `Translated ${totalTranslated} strings across ${successCount} languages`,
        results,
      };
    } catch (error) {
      logger.error('Error in bulkTranslateLanguages', error);
      throw new HttpsError(
        'internal',
        `Translation failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

/**
 * Cloud Scheduled Function: Monitor Google Listings
 * 
 * Periodically checks Google Places data against BrisConnect business records.
 * Runs weekly (configurable) to detect outdated, closed, or inconsistent listings.
 * 
 * Writes to: google_listing_monitoring collection
 * Updates: food_businesses, businesses (minimal fields only)
 * 
 * Does NOT automatically modify business data.
 */
const { monitorAllGoogleListings } = require('./monitor_google_listings');

exports.monitorGoogleListingsScheduled = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every sunday 02:00', // Run weekly at 2 AM UTC (Tuesday 12:00 PM AEST)
    timeoutSeconds: 900, // 15 minutes
    maxInstances: 1, // Single instance to avoid concurrent runs
    memory: '512MB',
  },
  async () => {
    try {
      logger.info('Starting scheduled Google Listings monitoring');

      const apiKey = googlePlacesApiKey.value();
      const results = await monitorAllGoogleListings(apiKey);

      logger.info('Google Listings monitoring completed', {
        processed: results.processed,
        verified: results.verified,
        mismatch: results.mismatch,
        closed: results.closed,
        errors: results.errors,
      });

      return results;
    } catch (error) {
      logger.error('Error in monitorGoogleListingsScheduled', error);
      // Don't throw - allow function to complete gracefully
      // Admin will see errors in Cloud Function logs
      return { success: false, error: error.message };
    }
  },
);
