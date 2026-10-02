# GoTRVL PH - First Admin Account Setup

This guide creates your **private admin account**. Only someone who completes
these steps can open the Admin Dashboard. Normal users can never reach it:
the entrance is hidden (triple-tap the Profile tab icon within 1.5 seconds),
and entry always requires a valid admin email + password **plus** the `admin`
role stored on the Firebase backend. There is no bypass.

## What you need

- Your Firebase project (see PUBLISHING.md for creating one)
- Email/Password sign-in **enabled**: Firebase Console → Authentication →
  Sign-in method → Email/Password → Enable
- Node.js 18+ on your computer
- The GoTRVL app installed with your Firebase config (`google-services.json` /
  `GoogleService-Info.plist`, see PUBLISHING.md)

## Steps

### 1. Create your owner user in Firebase Authentication

Firebase Console → Authentication → Users → **Add user**.
Enter the email and password you want for your admin account.
Use a strong, unique password. Copy the **UID** shown for this user.

(Alternative: sign up once inside the app's normal sign-up screen with your
admin email, then copy the UID from the Console.)

### 2. Download a service-account key (keep it secret)

Firebase Console → Project Settings → **Service accounts** →
**Generate new private key**. Save the JSON file somewhere safe on your
computer, for example `~/.secrets/gotrvl-admin.json`.

> Never commit this file to git, never email it, never paste it into the app.

### 3. Install the admin tool's dependency (one time)

```bash
cd ~/workspace/go-trvl-app/tools
npm install firebase-admin
```

### 4. Grant the admin claim

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/gotrvl-admin.json \
  node make_admin.js PASTE_THE_UID_HERE
```

You should see `Admin claim GRANTED for uid ...`. You can also pass the
email instead of the UID: `node make_admin.js you@example.com`.

### 5. Open the hidden Admin Login in the app

1. Open GoTRVL PH and make sure you are on any tab.
2. **Tap the Profile tab icon 3 times quickly (within 1.5 seconds).**
   Nothing in the normal UI mentions Admin; single and double taps keep
   working exactly as before.
3. The **Admin Access** login screen appears. Sign in with the admin
   email and password from step 1.
4. The app verifies your `admin` claim with Firebase before opening the
   **Admin Dashboard**. A non-admin account that finds the triple-tap gets
   signed straight back out with "Not an authorized admin account."

### 6. Use the dashboard

- **Overview**: real counts of users, posts, businesses, live streams,
  pending reports. (Saved trips live on-device; bookings happen on partner
  sites; revenue appears once `revenue_events` exists.)
- **Users**: suspend / unsuspend accounts. Suspended users are signed out
  and blocked at the next sign-in.
- **Moderation**: review reported posts; dismiss, remove the post, or
  suspend the author.
- **Content**: approve or reject pending business listings. (Travel
  destinations/provinces ship as bundled JSON assets and update with app
  releases.)
- **Marketplace**: toggle Featured placement and Free/Premium tiers.
- **Live**: view streams and end them if needed.
- **Announcements**: publish in-app announcements.
- **Settings**: flip feature flags (`affiliatesEnabled`, `adsEnabled`,
  `liveEnabled`, `premiumComingSoon`) without a new build.
- **Logout** (top-right) signs you out of the admin session completely.

The dashboard is responsive: it works on your phone inside the app, and on
a computer via `flutter build web`.

## Revoking admin access

```bash
GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/gotrvl-admin.json \
  node make_admin.js PASTE_THE_UID_HERE --revoke
```

The claim is removed and refresh tokens are revoked, so the account loses
admin access immediately on next sign-in.

## Security notes

- The admin role is a Firebase **custom claim**, enforced by Firestore
  security rules on the server. Client-side checks alone are never trusted.
- Admin credentials live only in Firebase Authentication, never in the
  app's code or config files.
- If your admin password is ever exposed: change it in Firebase Console →
  Authentication, then re-run `make_admin.js` (the claim survives a
  password change).
- Deploy `firestore.rules` and test in the Firestore emulator before
  production (see PUBLISHING.md).
