# GoTRVL - Publishing Guide (Google Play + App Store)

*Last updated: September 29, 2026. This file is the single source of truth for
submitting GoTRVL to both stores. If another doc disagrees with this one, this
one wins.*

## 0. What you're publishing

- **One Flutter codebase** (`lib/`) produces two native apps: Android
  (`android/`) and iOS (`ios/`).
- Package name / bundle ID: **`com.gotrvl.app`** (identical on both stores).
- Backend: **Firebase** (Auth, Firestore, Storage), free Spark tier to start.
- Maps: **Google Maps SDK** with a custom bohemian style (`assets/map_style.json`).
- Content: 83 provinces + 37 tourist destinations bundled as JSON
  (`assets/data/`), 408 province cities/towns. All travel-guide copy is original
  GoTRVL content; Google Maps supplies base tiles and directions links only.
- Monetization boundary (see `MONETIZATION_POLICY.md`): the app never moves
  money between users. No wallets, no send-money flows. Bookings route to
  external authorized partners via disclosed affiliate links.

## 1. Versioning

Current version: **`1.0.0+1`** (`version: 1.0.0+1` in `pubspec.yaml`).

Where to bump: **only `pubspec.yaml`**. The format is `X.Y.Z+N`:

| Part | Meaning | Where it lands |
|---|---|---|
| `X.Y.Z` | `versionName` (Android) / `CFBundleShortVersionString` (iOS); the version users see | Play listing, App Store listing |
| `N` | `versionCode` (Android) / `CFBundleVersion` (iOS); must increase with every upload | `android/app/build.gradle.kts` reads it via `flutter.versionCode` / `flutter.versionName`; iOS gets it via `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` at build time |

Rules:

- Never edit version numbers in `build.gradle.kts` or `Info.plist` by hand;
  they derive from `pubspec.yaml`.
- Every new store upload needs a higher `+N` build number, even if the
  user-facing version is unchanged.
- Convention: features `1.1.0+2`, fixes `1.0.1+3`, and so on.

## 2. Verification status and known gaps

Honest status as of September 29, 2026:

| Check | Status |
|---|---|
| `flutter analyze` | Clean, no issues |
| Unit tests | 64 passing |
| `targetSdk` / `compileSdk` 36, `minSdk` 24 | Set in `android/app/build.gradle.kts` |
| Apple privacy manifest (`PrivacyInfo.xcprivacy`) | Present (`NSPrivacyTracking=false`) |
| In-app account deletion (Apple 5.1.1(v)) | Implemented: Profile -> Settings -> Delete Account |
| UGC moderation (report, block, EN+Tagalog filter) | Implemented |
| Hidden admin console | Implemented (triple-tap Profile icon + backend `admin` custom claim) |

Known gaps you must close before submitting (also in the Owner Action List):

- **Firebase plugins are a major version behind** current releases. Do the
  upgrade pass before submission (it also keeps Apple SDK-signature and
  privacy-manifest requirements satisfied).
- **`firestore.rules` and `storage.rules` were changed but never
  syntax-validated** (no Firebase CLI in this environment). Deploy them and
  test with the Firebase emulator before launch.
- **No APK/AAB has been built here**: the Gradle daemon is broken in this
  Linux build environment. Build the release bundle on a working machine.
- **No real-device testing** has been done yet.
- **Google Maps keys are placeholders**: `YOUR_ANDROID_MAPS_API_KEY` in
  `android/app/src/main/AndroidManifest.xml`; iOS `AppDelegate.swift` does not
  yet call `GMSServices.provideAPIKey` (add it when you have the key).
- **No store screenshots, feature graphic, or hosted privacy-policy URL** exist
  yet.
- The **`[YOUR SUPPORT EMAIL]` placeholder appears 4 times** across the repo
  (see Owner Action List).

## 3. Accounts and fees

| Account | Cost | Where |
|---|---|---|
| Google Play Console | **$25 one-time** | https://play.google.com/console |
| Apple Developer Program | **$99/year** | https://developer.apple.com/programs/ |
| Firebase / Google Cloud | Free Spark tier to start; **billing must be enabled** for Maps API | https://console.firebase.google.com |

Enroll with the legal name you want shown as the seller. Google identity
verification takes 1-3 days; Apple enrollment review takes about 24-48h.

## 4. Google Play: closed-test gate and target API level

Two Play policies that shape your launch plan:

1. **Personal-account closed-test gate.** A first app on a personal Play
   Console account cannot go to production until it has run a **closed test
   with at least 12 testers for 14 consecutive days**. Recruit your testers
   early (friends, family, travel groups); the 14-day clock starts when the
   closed test goes live, not when you create it.
2. **Target API 36.** New apps and app updates submitted on or after
   **August 31, 2026** must target API level 36. This project already does
   (`targetSdk = 36`, `compileSdk = 36`, `minSdk = 24` in
   `android/app/build.gradle.kts`). If you ever need more time on a future
   target-API deadline, Play Console lets you request an extension to
   **November 1, 2026** (Policy status -> target API extension request).

## 5. Android release signing

1. Create your upload keystore (guard this file and both passwords like
   production secrets; losing them means you can never update the app):
   ```bash
   keytool -genkey -v -keystore ~/gotrvl-upload-key.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias gotrvl
   ```
2. Copy `android/key.properties.example` to `android/key.properties` (drop
   `.example`) and fill in the real values:
   ```
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=gotrvl
   storeFile=/home/you/gotrvl-upload-key.jks
   ```
   **Never commit `key.properties`.** It is git-ignored. If it is absent,
   release builds fall back to debug signing so local builds still work; never
   upload such a build to Play.
3. Build the release bundle (on a machine with a working Gradle setup):
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.

## 6. Data Safety form (Play Console) - answers

Use these in the Play Console **Data safety** form. The full verbatim answers
live in `data-safety.md` (which also covers App Store Connect App Privacy).

| Data type | Collected | Shared | Notes |
|---|---|---|---|
| Name, email address | Yes | No | Account creation and profile display |
| Firebase UID (user IDs) | Yes | No | Auth identifier |
| Photos and videos | Yes | No | User post/profile photos in Firebase Storage; visible to other users in-app by design |
| Approximate location | Yes | No | Map position and directions; optional, app works without the permission |
| In-app messages (chat) | Yes | No | Required for messaging |
| User-generated content (posts, comments, LIVE chat) | Yes | No | Social features |
| App activity (likes, matches, places marked done, points) | Yes | No | Gamification |
| Business contact info (business owners: business name, phone, website, social links) | Yes | No | Shown publicly in the listing by design |
| Device or advertising IDs | No | No | No ad SDK bundled (house ads only) |

Security practices:

- **Data encrypted in transit: YES** (HTTPS/TLS via Firebase).
- **Data encrypted at rest: YES** (Firebase defaults).
- **Users can request data deletion: YES.** In-app path: Profile -> Settings
  -> Delete Account (double-confirm + re-authentication). Important: Firebase
  Auth `deleteUser` alone does **not** remove Firestore/Storage records; the
  app's Delete Account flow deletes the profile, posts, photos and messages.
- **Follows Families Policy: NO** (not a children's app; 13+).

## 7. Google Play submission steps

1. **Create the app** in Play Console: name **GoTRVL**, default language
   English, category Travel, package `com.gotrvl.app`.
2. **Upload the `.aab`** under Test and release -> Internal testing; add
   yourself as a tester and try the real build.
3. Complete the required declarations: **App content**, **Data safety** form
   (section 6 above), **Content rating** questionnaire, **Target audience**,
   **News apps** (no), **COVID contact tracing** (no), **Financial features**
   (no in-app payments or wallets; affiliate links open external partner sites
   in the browser), **Privacy policy URL** (host `privacy-policy.md` publicly,
   e.g. GitHub Pages).
4. **Store listing**: short description (80 chars max), full description (use
   `store-listing.md`), 512x512 icon, 1024x500 feature graphic, at least 2
   phone screenshots per form factor.
5. **Closed testing**: add at least 12 testers, run the closed test for 14
   days (required for a first app on a personal account before production
   access unlocks).
6. **Production -> Create new release** -> upload the `.aab` -> Rollout.
   Review typically takes 1-3 days.

## 8. App Store (Apple) submission

Needs a Mac with Xcode.

### 8a. UGC guideline 1.2 checklist

Apple requires these for apps with user-generated content. Status in this
build:

| Requirement | Status |
|---|---|
| Report objectionable content (posts, comments, chat messages, user profiles) | DONE (in-app reporting via moderation service) |
| Block abusive users | DONE (in-app block) |
| Filter objectionable content | DONE (content filter, English + Tagalog) |
| Published contact info for safety issues | DONE in code, **owner must replace** the `[YOUR SUPPORT EMAIL]` placeholder |
| In-app account deletion (guideline 5.1.1(v)) | DONE (Profile -> Settings -> Delete Account) |
| Demo login for App Review | **OWNER ACTION**: create a reviewer account in Firebase Auth and enter its email + password under App Review Information |

### 8b. TestFlight

- **Internal testing**: up to 100 users, no beta review; build available about
  30 minutes after upload. Use it to dogfood on your own iPhones.
- **External testing**: up to 10,000 testers, requires **beta review**
  (typically 24-48h). Good for the pre-launch travel-community test group.

### 8c. Privacy

- `ios/Runner/PrivacyInfo.xcprivacy` is present: `NSPrivacyTracking=false`,
  data types declared (name, email, photos/videos, coarse location,
  user-generated content), UserDefaults purpose `CA92.1` declared.
- App Store Connect **App Privacy** nutrition labels mirror `data-safety.md`.

### 8d. Third-party SDK signatures

Apple requires privacy manifests and valid signatures for its list of
commonly used third-party SDKs. **Keep the Firebase plugins current before
every submission** and re-check Apple's required-SDK list; the Firebase
upgrade pass in the Owner Action List covers this.

### 8e. Build and submit

1. On the Mac: `flutter build ipa --release` (output
   `build/ios/ipa/go_trvl.ipa`). First run: open `ios/Runner.xcworkspace` in
   Xcode once, select your Team in Signing & Capabilities, bundle ID
   `com.gotrvl.app`.
2. **App Store Connect** -> My Apps -> **+** -> name **GoTRVL**, bundle ID
   `com.gotrvl.app`, SKU `gotrvl001`.
3. Upload the `.ipa` with **Transporter** (free Mac app) or `xcrun altool`;
   it appears in TestFlight within about 30 minutes.
4. Complete the listing: screenshots (**6.7" and 6.5" required**, iPad
   optional), description (reuse `store-listing.md`), keywords, support URL,
   privacy policy URL, App Privacy labels.
5. Fill **App Review Information** with the demo login from 8a.
6. Submit for review; typically 24-48h.

## 9. Google Maps attribution

- The Google Maps SDK draws its attribution on the map automatically. Do not
  cover or obscure it with UI overlays.
- The privacy policy must link the Google Maps Terms of Service
  (https://maps.google.com/help/terms_maps/) and the Google Privacy Policy
  (https://policies.google.com/privacy). `privacy-policy.md` already does.

## 10. Store assets (none exist yet)

Capture these after Firebase and the Maps keys are working, on real devices
or emulators:

- **Play**: 512x512 app icon, 1024x500 feature graphic, at least 2 phone
  screenshots per form factor (plus 7" and 10" tablet shots if you support
  tablets).
- **App Store**: 6.7" and 6.5" screenshots required, iPad optional.
- **Privacy policy**: hosted at a public URL, linked from both store listings.

## 11. OWNER ACTION LIST

Do these in order. Items marked DONE are already handled in code.

### Firebase and backend

- [ ] Create Firebase project `go-trvl`; enable Email/Password auth; create
      Firestore (region `asia-southeast1`, production mode) and Storage.
- [ ] Paste and publish `firestore.rules` and `storage.rules`, then validate
      them with the Firebase emulator (they were never syntax-checked here).
- [ ] Register the Android and iOS apps in Firebase; download
      `google-services.json` into `android/app/` and `GoogleService-Info.plist`
      into `ios/Runner/` (add the plist via Xcode so it registers).
- [ ] Run `flutterfire configure` once, then wire `DefaultFirebaseOptions`
      into `lib/main.dart` (see the old step 2 notes in git history if needed).
- [ ] Create the App Review demo login in Firebase Auth (email + password)
      for Apple's reviewers.
- [ ] Set up the first admin account per `ADMIN_SETUP.md` (service-account key
      kept off-device + `tools/make_admin.js` to grant the `admin` claim).
      DONE in code: hidden triple-tap console + backend claim check.

### Google Maps

- [ ] In Google Cloud Console: enable **Maps SDK for Android** and **Maps SDK
      for iOS**; enable billing on the project.
- [ ] Create a restricted API key (Android: package `com.gotrvl.app` + SHA-1;
      iOS: bundle `com.gotrvl.app`).
- [ ] Replace `YOUR_ANDROID_MAPS_API_KEY` in
      `android/app/src/main/AndroidManifest.xml`.
- [ ] Add `GMSServices.provideAPIKey("YOUR_KEY")` in
      `ios/Runner/AppDelegate.swift` (the call does not exist yet).

### Release signing

- [ ] Create the upload keystore with `keytool` (section 5); guard the file
      and both passwords like production secrets.
- [ ] Copy `android/key.properties.example` to `android/key.properties` and
      fill in real values. Never commit it.

### Monetization gates

- [ ] Affiliate partners: paste real affiliate IDs in
      `lib/config/affiliate_config.dart` and set `affiliatesEnabled = true`
      ONLY when ready. Currently off with `YOUR_AFFILIATE_ID` placeholders, so
      all affiliate UI stays hidden. Outbound links open in the browser; the
      app shares no personal data with partners.
- [ ] In-app products (Play Console + App Store Connect): create the four
      product IDs in `lib/services/billing_service.dart`
      (`gotrvl_premium_traveler_monthly` ~₱100/mo, `gotrvl_place_unlock`
      ~₱10–₱20, `gotrvl_business_featured`, `gotrvl_business_premium` ~₱100),
      add bank + tax info for payouts, and set `BillingService.debugBypass =
      false` before any store release. Test builds keep the clearly-marked
      TEST MODE bypass (no real charge).
- [ ] Video calls / LIVE streaming: create your own video-provider account
      (e.g. Agora), paste the App ID/token into
      `lib/services/video_call_service.dart` (`VideoCallConfig`). Until then
      the app shows "coming soon" — never invent credentials.
- [ ] If you ever add AdMob or another ad SDK, update `data-safety.md` and the
      App Privacy labels first (currently house ads only, no ad SDK).
- [ ] Read `MONETIZATION_POLICY.md`: no peer-to-peer money movement, ever.

### Content, legal, placeholders

- [ ] Replace all **4** `[YOUR SUPPORT EMAIL]` placeholders with the real
      support email: `privacy-policy.md` (1), `data-safety.md` (1),
      `lib/screens/profile_screen.dart` (2).
- [ ] Host `privacy-policy.md` at a public URL; use it for the Play Data
      safety privacy-policy field and the App Store privacy policy URL.
- [ ] Produce screenshots, feature graphic, and store icon (none exist yet;
      see section 10).

### Testing before submission

- [ ] Firebase plugin upgrade pass (currently a major version behind).
- [ ] Build the release AAB on a working machine (Gradle daemon is broken in
      this Linux environment) and test on real Android and iOS devices.
- [ ] Recruit at least 12 closed-test testers; run the 14-day closed test on
      Play (required for a first app on a personal account).

### After launch

- [ ] Bump `version` in `pubspec.yaml` for every release (section 1).
- [ ] Enable Crashlytics in Firebase Console (one click) and watch Play
      Console / App Store Connect analytics.
- [ ] New destinations: drop more JSON into `assets/data/` and rebuild; no
      backend change needed.
