const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function triggerCrowdReport() {
  const now = new Date();
  const timestamp = now.toISOString();
  
  // Create a crowd report that triggers admin notification
  const reportRef = admin.firestore().collection('crowd_reports').doc();
  
  await reportRef.set({
    eventId: 'E5uL24vmOi9tVDGdMMGE',
    intensity: 'moderate',
    visitorCount: Math.floor(Math.random() * 100) + 20,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    visitorId: 'test-visitor-' + Date.now(),
    status: 'submitted',
  });

  console.log('Crowd report created: ' + reportRef.id);
  
  // Also manually create the admin notification to test the display
  const adminNotificationRef = admin.firestore().collection('admin_notifications').doc();
  
  await adminNotificationRef.set({
    adminEmail: 'brisconnect0@gmail.com',
    title: '👥 Crowd Report Test - ' + timestamp,
    message: 'Live test crowd report submitted for Live Test Crowd Report Event. Current intensity: moderate',
    type: 'crowd_report',
    data: {
      eventId: 'E5uL24vmOi9tVDGdMMGE',
      reportId: reportRef.id,
      intensity: 'moderate',
      timestamp: timestamp,
    },
    relatedItemId: 'E5uL24vmOi9tVDGdMMGE',
    relatedItemType: 'event',
    actionRoute: '/admin/reports',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('Admin notification created: ' + adminNotificationRef.id);
  console.log('✅ Notification should now appear in admin dashboard');
}

triggerCrowdReport().catch(console.error);
