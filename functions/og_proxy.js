const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { onRequest } = require('firebase-functions/v2/https');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const DEFAULT_OG = {
  title: 'BrisConnect+ — Discover Brisbane',
  description:
    'Discover local food events, businesses and experiences in Brisbane with BrisConnect+',
  image: 'https://brisconnect-68b78.web.app/assets/assets/brisconnect_icon.png',
  url: 'https://brisconnect-68b78.web.app',
};

/**
 * Serves an HTML page with Open Graph meta tags for social crawlers and a
 * client-side redirect for human visitors to the Flutter web app.
 *
 * Facebook, Instagram and TikTok crawlers do not execute JavaScript, so they
 * will index the meta tags rendered by this function. Human browsers will run
 * the redirect script and land in the Flutter app at the matching deep link.
 */
const ogProxy = onRequest(
  {
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (req, res) => {
    try {
      const path = (req.path || '/').replace(/^\//, '').replace(/\/$/, '');
      const segments = path.split('/').filter(Boolean);
      const [type, id] = segments;

      const og = await _resolveOgTags(type, id, req.query);

      res.set('Content-Type', 'text/html; charset=utf-8');
      res.status(200).send(_renderHtml(og, req.url));
    } catch (err) {
      logger.error('Error rendering OG tags', err);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.status(200).send(_renderHtml(DEFAULT_OG, req.url));
    }
  },
);

async function _resolveOgTags(type, id, query) {
  if (!type || !id) {
    return DEFAULT_OG;
  }

  const slugName = String(query.name || '').trim();
  const baseUrl = `https://brisconnect-68b78.web.app/${type}/${id}`;

  if (type === 'event') {
    const collections = ['events', 'business_events'];
    for (const collection of collections) {
      const doc = await db.collection(collection).doc(id).get();
      if (doc.exists) {
        const data = doc.data() || {};
        return {
          title: _firstNonEmpty(data.title, slugName, DEFAULT_OG.title),
          description: _firstNonEmpty(
            data.description,
            data.shortDescription,
            DEFAULT_OG.description,
          ),
          image: _firstNonEmpty(data.imageUrl, DEFAULT_OG.image),
          url: baseUrl,
        };
      }
    }
  }

  // business, food and venue all resolve against the businesses collection.
  const doc = await db.collection('businesses').doc(id).get();
  if (doc.exists) {
    const data = doc.data() || {};
    return {
      title: _firstNonEmpty(data.businessName, data.name, slugName, DEFAULT_OG.title),
      description: _firstNonEmpty(
        data.description,
        data.tagline,
        data.cuisine,
        DEFAULT_OG.description,
      ),
      image: _firstNonEmpty(data.logoUrl, data.imageUrl, DEFAULT_OG.image),
      url: baseUrl,
    };
  }

  return {
    ...DEFAULT_OG,
    title: slugName || DEFAULT_OG.title,
    url: baseUrl,
  };
}

function _firstNonEmpty(...values) {
  for (const value of values) {
    if (value && String(value).trim().length > 0) {
      return String(value).trim();
    }
  }
  return '';
}

function _escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function _renderHtml(og, requestUrl) {
  const encodedTitle = _escapeHtml(og.title);
  const encodedDescription = _escapeHtml(og.description);
  const encodedImage = _escapeHtml(og.image);
  const encodedUrl = _escapeHtml(og.url);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${encodedTitle}</title>
  <meta name="description" content="${encodedDescription}">

  <meta property="og:site_name" content="BrisConnect+">
  <meta property="og:title" content="${encodedTitle}">
  <meta property="og:description" content="${encodedDescription}">
  <meta property="og:image" content="${encodedImage}">
  <meta property="og:url" content="${encodedUrl}">
  <meta property="og:type" content="website">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${encodedTitle}">
  <meta name="twitter:description" content="${encodedDescription}">
  <meta name="twitter:image" content="${encodedImage}">

  <link rel="canonical" href="${encodedUrl}">

  <script>
    // Human visitors: redirect into the Flutter web app while preserving the path.
    (function () {
      var appUrl = 'https://brisconnect-68b78.web.app' + window.location.pathname + window.location.search;
      if (window.location.href !== appUrl) {
        window.location.replace(appUrl);
      }
    })();
  </script>
</head>
<body>
  <noscript>
    <h1>${encodedTitle}</h1>
    <p>${encodedDescription}</p>
    <p>Open this link in the BrisConnect+ app to see more.</p>
  </noscript>
</body>
</html>`;
}

module.exports = { ogProxy };
