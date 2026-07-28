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

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message', payload);
  const notificationTitle = payload.notification?.title || 'BrisConnect+';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
