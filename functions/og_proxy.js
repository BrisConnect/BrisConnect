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
  image: 'https://brisconnect-68b78.web.app/assets/assets/images/brisconnect_logo.png',
  imageWidth: '1200',
  imageHeight: '630',
  url: 'https://brisconnect-68b78.web.app',
};

// Common social media / messenger crawlers that need OG tags.
const CRAWLER_UA_RE = /facebookexternalhit|fb_iab|instagram|tiktok|twitterbot|whatsapp|linkedinbot|googlebot|bingbot|slackbot|discordbot|telegrambot|applebot/i;

/**
 * Serves an HTML page with Open Graph meta tags for social crawlers and the
 * Flutter web app bootstrap for human visitors.
 *
 * Facebook, Instagram and TikTok crawlers do not execute JavaScript, so they
 * receive the OG tag HTML. Human browsers (including in-app browsers opened by
 * QR-code scans) receive the Flutter bootstrap so the app actually loads at the
 * requested deep link.
 */
const ogProxy = onRequest(
  {
    region: 'australia-southeast1',
    cors: true,
    // Every shared business/event link click and crawler preview fetch hits
    // this function, so a low cap here would bottleneck sharing during a
    // popular event. Raised from 10 to handle high-volume viral sharing.
    maxInstances: 100,
  },
  async (req, res) => {
    try {
      const path = (req.path || '/').replace(/^\//, '').replace(/\/$/, '');
      const segments = path.split('/').filter(Boolean);
      const [type, id] = segments;
      const userAgent = String(req.headers['user-agent'] || '');
      const isCrawler = CRAWLER_UA_RE.test(userAgent);

      const og = await _resolveOgTags(type, id, req.query);

      res.set('Content-Type', 'text/html; charset=utf-8');
      if (isCrawler) {
        res.status(200).send(_renderOgHtml(og));
      } else {
        res.status(200).send(_renderAppHtml(og));
      }
    } catch (err) {
      logger.error('Error rendering OG tags', err);
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.status(200).send(_renderOgHtml(DEFAULT_OG));
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
        return _buildOg(
          _firstNonEmpty(data.title, slugName, DEFAULT_OG.title),
          _firstNonEmpty(
            data.description,
            data.shortDescription,
            DEFAULT_OG.description,
          ),
          _firstNonEmpty(data.imageUrl, DEFAULT_OG.image),
          baseUrl,
        );
      }
    }
  }

  if (type === 'promotion') {
    const doc = await db.collection('promotions').doc(id).get();
    if (doc.exists) {
      const data = doc.data() || {};
      return _buildOg(
        _firstNonEmpty(data.title, slugName, DEFAULT_OG.title),
        _firstNonEmpty(
          data.description,
          data.discount,
          DEFAULT_OG.description,
        ),
        _firstNonEmpty(data.imageUrl, DEFAULT_OG.image),
        baseUrl,
      );
    }
  }

  // business, food and venue all resolve against the businesses collection,
  // then fall back to the legacy food_businesses collection for seeded/demo
  // food profiles that pre-date the canonical business schema.
  const collections = ['businesses', 'food_businesses'];
  for (const collection of collections) {
    const doc = await db.collection(collection).doc(id).get();
    if (doc.exists) {
      const data = doc.data() || {};
      return _buildOg(
        _firstNonEmpty(data.businessName, data.name, data.title, slugName, DEFAULT_OG.title),
        _firstNonEmpty(
          data.description,
          data.tagline,
          data.cuisine,
          DEFAULT_OG.description,
        ),
        _firstNonEmpty(data.logoUrl, data.imageUrl, data.coverImageUrl, DEFAULT_OG.image),
        baseUrl,
      );
    }
  }

  return _buildOg(
    slugName || DEFAULT_OG.title,
    DEFAULT_OG.description,
    DEFAULT_OG.image,
    baseUrl,
  );
}

function _buildOg(title, description, image, url) {
  return {
    title,
    description,
    image,
    imageWidth: DEFAULT_OG.imageWidth,
    imageHeight: DEFAULT_OG.imageHeight,
    url,
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

function _renderOgHtml(og) {
  const encodedTitle = _escapeHtml(og.title);
  const encodedDescription = _escapeHtml(og.description);
  const encodedImage = _escapeHtml(og.image);
  const encodedUrl = _escapeHtml(og.url);
  const encodedImageWidth = _escapeHtml(og.imageWidth || DEFAULT_OG.imageWidth);
  const encodedImageHeight = _escapeHtml(og.imageHeight || DEFAULT_OG.imageHeight);

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
  <meta property="og:image:width" content="${encodedImageWidth}">
  <meta property="og:image:height" content="${encodedImageHeight}">
  <meta property="og:url" content="${encodedUrl}">
  <meta property="og:type" content="website">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${encodedTitle}">
  <meta name="twitter:description" content="${encodedDescription}">
  <meta name="twitter:image" content="${encodedImage}">

  <link rel="canonical" href="${encodedUrl}">
</head>
<body>
  <h1>${encodedTitle}</h1>
  <p>${encodedDescription}</p>
  <p>Open this link in the BrisConnect+ app to see more.</p>
</body>
</html>`;
}

/**
 * Serves the Flutter web app bootstrap HTML at the requested deep-link path.
 * This is the same content Firebase Hosting normally serves from index.html,
 * inlined here so the Cloud Function can return it for human visitors while
 * crawlers still receive the OG tag page.
 */
function _renderAppHtml(og) {
  const encodedTitle = _escapeHtml(og.title);
  const encodedDescription = _escapeHtml(og.description);
  const encodedImage = _escapeHtml(og.image);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, viewport-fit=cover">
  <meta name="description" content="${encodedDescription}">

  <meta property="og:site_name" content="BrisConnect+">
  <meta property="og:title" content="${encodedTitle}">
  <meta property="og:description" content="${encodedDescription}">
  <meta property="og:image" content="${encodedImage}">
  <meta property="og:type" content="website">
  <meta name="twitter:card" content="summary_large_image">

  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="BrisConnect+">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/svg+xml" href="brisconnect_icon.svg"/>

  <title>${encodedTitle}</title>
  <link rel="manifest" href="manifest.json">
  <link rel="preload" href="assets/fonts/MaterialIcons-Regular.otf" as="font" type="font/otf" crossorigin>
  <style>
    @font-face {
      font-family: 'MaterialIcons';
      src: url('assets/fonts/MaterialIcons-Regular.otf') format('opentype');
      font-weight: normal;
      font-style: normal;
    }
    html, body { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
    body { background-color: #ffffff; font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    #app { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="app"></div>
  <script>
    function loadFlutterBootstrap() {
      var script = document.createElement('script');
      script.src = 'flutter_bootstrap.js';
      document.body.appendChild(script);
    }
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function (registrations) {
        return Promise.all(registrations.map(function (registration) { return registration.unregister(); }));
      }).then(loadFlutterBootstrap).catch(loadFlutterBootstrap);
    } else {
      loadFlutterBootstrap();
    }
  </script>
</body>
</html>`;
}

module.exports = { ogProxy };
