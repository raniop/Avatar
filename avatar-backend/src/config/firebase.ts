import admin from 'firebase-admin';

// Initialize Firebase Admin SDK with service account credentials
// Required for FCM push notifications (projectId alone isn't enough)
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;

console.log('[Firebase] FIREBASE_SERVICE_ACCOUNT exists:', !!serviceAccountJson);
console.log('[Firebase] FIREBASE_SERVICE_ACCOUNT length:', serviceAccountJson ? serviceAccountJson.length : 0);

let firebaseApp: admin.app.App;

if (serviceAccountJson) {
  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    console.log('[Firebase] Parsed service account, project_id:', serviceAccount.project_id);
    console.log('[Firebase] Has private_key:', !!serviceAccount.private_key);
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('[Firebase] Initialized with service account credentials ✅');
  } catch (e: any) {
    console.error('[Firebase] Failed to parse service account:', e.message);
    firebaseApp = admin.initializeApp({ projectId: 'avatar-dc52f' });
    console.log('[Firebase] Fallback: initialized with projectId only ⚠️');
  }
} else {
  firebaseApp = admin.initializeApp({ projectId: 'avatar-dc52f' });
  console.log('[Firebase] No service account found, initialized with projectId only ⚠️');
}

export const firebaseAuth = admin.auth();
export const firebaseMessaging = admin.messaging();
export default firebaseApp;
