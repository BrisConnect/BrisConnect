// BrisConnect+ Firebase Cloud Messaging service worker.
// This file is required by the Firebase Messaging SDK on web. It handles
// background push notifications when the app is not in focus.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Minimal stub configuration. The in-app Firebase Messaging integration
// should call getToken with the same configuration and vapidKey.
firebase.initializeApp({
  apiKey: 'AIzaSyCgEZo0LJD6ksf9Vfe8owyGm22xYygW8ps',
  authDomain: 'brisconnect-68b78.firebaseapp.com',
  projectId: 'brisconnect-68b78',
  storageBucket: 'brisconnect-68b78.appspot.com',
  messagingSenderId: '2073694703',
  appId: '1:2073694703:web:26b39fb2f42c4adc01c61a',
});

const messaging = firebase.messaging();

// Legacy short screen codes used by owner/visitor/admin Cloud Functions,
// mapped to real app routes. Kept in sync with the routeName resolution in
// lib/services/fcm_service.dart's _navigateForMessage().
const LEGACY_SCREEN_ROUTES = {
  business_dashboard: '/local/portal',
  business_detail: '/business/view',
  reviews: '/admin/reports',
  promotion_detail: '/promotion/detail',
};

// Resolves a notification's data payload to a URL path the app can open on a
// cold boot. Prefers true URL-path deep links (e.g. /business/<id>) over
// named routes like /business/view, since named routes only work via
// in-memory Navigator arguments and are unreachable from a fresh page load.
function resolveDeepLinkPath(data) {
  const screen = data.screen || '';
  const routeName = LEGACY_SCREEN_ROUTES[screen] || screen || '/';
  const businessId = data.businessId;
  const eventId = data.eventId;

  if (routeName === '/business/view' && businessId) {
    return `/business/${businessId}`;
  }
  if (routeName === '/event/view' && eventId) {
    return `/event/${eventId}`;
  }
  if (routeName === '/promotion/detail') {
    return businessId ? `/business/${businessId}` : '/visitor/portal';
  }
  return routeName.startsWith('/') ? routeName : `/${routeName}`;
}

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message', payload);
  const notificationTitle = payload.notification?.title || 'BrisConnect+';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    // Without this, clicking the notification has no idea what to open.
    data: payload.data || {},
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handles taps on notifications shown while the app tab was backgrounded or
// closed. Without this listener the browser just focuses/opens the site
// root, ignoring the notification's deep link entirely.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = new URL(
    resolveDeepLinkPath(event.notification.data || {}),
    self.location.origin,
  ).href;

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url.startsWith(self.location.origin) && 'focus' in client) {
            return client.focus().then(() => {
              if ('navigate' in client) return client.navigate(targetUrl);
            });
          }
        }
        if (clients.openWindow) return clients.openWindow(targetUrl);
      }),
  );
});
