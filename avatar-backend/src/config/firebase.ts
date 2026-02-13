import admin from 'firebase-admin';

// Initialize Firebase Admin SDK
// Uses Application Default Credentials or GOOGLE_APPLICATION_CREDENTIALS env var
// For development, the project ID is enough to verify ID tokens
const firebaseApp = admin.initializeApp({
  projectId: 'avatar-dc52f',
});

export const firebaseAuth = admin.auth();
export default firebaseApp;
