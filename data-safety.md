# GoTRVL - Data Safety (Play Console) / App Privacy (App Store) answers

Use these answers verbatim in the Play Console **Data safety** form and the
App Store Connect **App Privacy** labels. The submission walkthrough is in
`PUBLISHING.md` (the single source of truth).

## Does the app collect or share user data? - YES

### Personal info: Name, Email address
- Collected: YES - account creation and profile display.
- Shared: NO.

### Personal info: User IDs (Firebase UID)
- Collected: YES - Firebase Authentication identifier.
- Shared: NO.

### Photos and videos
- Collected: YES - user-attached post and profile photos, stored in Firebase
  Storage.
- Shared: NO (visible to other users in-app by design).

### Location (approximate)
- Collected: YES - used for in-app map position and directions.
- Shared: NO (never uploaded; stays on device).
- Optional: YES - the app works without granting location permission.

### App activity: In-app interactions (likes, comments, matches, places marked done, points)
- Collected: YES - core gamification and social features.
- Shared: NO.

### Messages (chat content)
- Collected: YES - required for the messaging feature.
- Shared: NO.

### User-generated content (posts, comments, LIVE stream chat)
- Collected: YES - feed posts, comments, and LIVE chat messages.
- Shared: NO (visible to other users in-app by design).

### Business listings (business owners only)
- Collected: YES - business contact info submitted by business owners
  (business name, category, phone, website, social links) to publish listings.
- Shared: NO (shown publicly in the listing by design, not sent to third
  parties).

### Admin role
- Collected: YES - admin email address, used only to gate the hidden admin
  console together with a backend `admin` custom claim.
- Shared: NO.

### Ads
- The app shows house/promotional slots only. **No third-party ad SDK is
  bundled and no data is collected for advertising.** If AdMob or another ad
  SDK is added later, this form must be updated.

### Affiliate links
- Currently disabled (config-gated, off by default). When enabled, tapping a
  partner button opens the partner website in the browser. The app shares no
  personal data with affiliates; data collected by the partner site is
  governed by the partner's own privacy policy.

### Device or other IDs (including advertising ID)
- Collected: NO - no ad SDK is bundled.

## Security practices
- Data encrypted in transit: YES (HTTPS/TLS via Firebase).
- Data encrypted at rest: YES (Firebase defaults).
- Users can request data deletion: YES. In-app path: Profile -> Settings ->
  Delete Account (double-confirm plus re-authentication). Note: Firebase Auth
  `deleteUser` alone does not remove Firestore/Storage records; the app's
  Delete Account flow deletes the profile, posts, photos and messages.
  Support contact: [YOUR SUPPORT EMAIL].
- Follows Families Policy: NO (not a children's app; 13+).
