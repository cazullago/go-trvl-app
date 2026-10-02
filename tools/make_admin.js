/**
 * make_admin.js - grant or revoke the GoTRVL PH admin role.
 *
 * The admin role is a Firebase Auth CUSTOM CLAIM ({ admin: true }). It lives
 * only on the backend. The Flutter app never contains credentials and never
 * grants admin access on its own; it only verifies this claim after a normal
 * email/password sign-in.
 *
 * PREREQUISITES
 *  1. Node 18+ installed.
 *  2. `npm install firebase-admin` (run once, in this tools/ directory).
 *  3. A Firebase service-account key: Firebase Console → Project Settings →
 *     Service Accounts → "Generate new private key". Save the JSON file
 *     somewhere SAFE (NOT inside the project repo).
 *
 * USAGE
 *  Grant:
 *    GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json \
 *      node make_admin.js <uid-or-email>
 *  Revoke:
 *    GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json \
 *      node make_admin.js <uid-or-email> --revoke
 *
 * SECURITY NOTES
 *  - Never commit the service-account JSON to git or share it.
 *  - Only run this on a machine you trust.
 *  - The admin's email/password is managed in Firebase Authentication like
 *    any other user; use a strong, unique password and enable MFA if needed.
 */

const admin = require('firebase-admin');

async function main() {
  const [target, flag] = process.argv.slice(2);
  if (!target) {
    console.error('Usage: node make_admin.js <uid-or-email> [--revoke]');
    process.exit(1);
  }
  const revoke = flag === '--revoke';

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  // Resolve email -> uid when an email address is given.
  let uid = target;
  if (target.includes('@')) {
    const user = await admin.auth().getUserByEmail(target);
    uid = user.uid;
  }

  const before = (await admin.auth().getUser(uid)).customClaims || {};
  const claims = { ...before };
  if (revoke) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await admin.auth().setCustomUserClaims(uid, claims);

  // Force token refresh so the claim takes effect on next sign-in.
  await admin.auth().revokeRefreshTokens(uid);

  console.log(
    revoke
      ? `Admin claim REVOKED for uid ${uid}.`
      : `Admin claim GRANTED for uid ${uid}.`
  );
  console.log(
    'Note: the user must sign in again (or the app refreshes the ID token) ' +
      'before the dashboard will accept them.'
  );
}

main().catch((e) => {
  console.error('Failed:', e.message);
  process.exit(1);
});
