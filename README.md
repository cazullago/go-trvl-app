# GoTRVL PH

A gamified travel-social app for the Philippines. Explore 83 provinces and
37 tourist destinations on the map, open places to see live weather, tap
pins to discover where to go / things to do / where to eat, **mark places
done** to earn points and climb from New Traveler to Alamat (all 120
passport stamps), post quest memories, share posts/stories/invitations in
the feed, go live, match with travel buddies, chat (1:1 + groups +
video-call ready), and browse the travel marketplace — all wrapped in a
bohemian tropical-island design with Filipino sticker accents.

Bottom tabs: Map · Feed · Create Post (center +) · Matching · Profile.

## Project layout

```
lib/
  main.dart                 App entry (Firebase init, providers, routes)
  theme/boho_theme.dart     Boho palette, fonts, decorations, map categories
  models/models.dart        Destination, Place, QuestPlace, AppUser, Post,
                            Memory, TravelInvitation, Chat, Buddy…
  models/monetization_models.dart  BusinessListing (+featured/quest-stop)…
  config/maps_config.dart   Google Maps key flag (graceful fallback w/o key)
  services/
    data_service.dart       Loads assets/data/*.json, search
    quest_service.dart      Loads assets/data/quest_places.json (quest pins)
    game_service.dart       Points, levels, passport stamps, map-unlock rules
    memory_service.dart     Firestore 'memories' (quest memories)
    weather_service.dart    Open-Meteo live weather (no key needed)
    permission_service.dart Point-of-use permission prompts + settings redirect
    billing_service.dart    Play/App Store billing + clearly-marked test bypass
    video_call_service.dart Video-provider integration layer (key = user's)
    auth_service.dart       Firebase email/password auth
    database_service.dart   Firestore: gamification, feed, likes, matching, chat
  screens/
    splash_screen.dart      Animated boho splash
    login_screen.dart / signup_screen.dart   (+ basic profile details)
    onboarding_tutorial.dart  Short tutorial: tabs, game, map-unlock rules
    home_shell.dart         Bottom nav: Map · Feed · Create · Matching · Profile
    map_screen.dart         Map + Discover sheet + quest pins + unlock gating
    place_detail_sheet.dart Place detail: weather, filters, quest, memories
    feed_screen.dart        Go Feed + stories + invitations + level badges
    create_post_screen.dart New Post: Post / Story / Live + Travel Invitation
    messages_screen.dart / chat_screen.dart  (4 sections, groups, video call)
    notifications_screen.dart  Likes/comments/follows/invites (+ teaser rule)
    marketplace_screen.dart Travel marketplace (featured pinned on top)
    matching_screen.dart    Swipe-to-match travel buddies (18+)
    profile_screen.dart     Cover/avatar, memories, level, passport stamps
    settings_screen.dart / legal_screen.dart
    leaderboard_screen.dart Points ranking
  widgets/marker_icon.dart  Custom boho map pins drawn on canvas
  widgets/level_badge.dart  "Lv.N" badge shown next to names everywhere
  widgets/ph_stickers.dart  Filipino sticker decorations (coconut, sun, waves…)
assets/
  data/provinces.json               83 provinces (82 + Metro Manila)
  data/destinations_{luzon,visayas,mindanao,new_1,new_2}.json
                                       37 destinations, ~580 places
  data/quest_places.json            Quest pins (target 50–100 per filter)
  map_style.json            Bohemian Google Maps style
  icon/gotrvl_icon.png      App icon source
```

## Content model (important)

Google Maps supplies the **base map tiles and directions links**. All
destination descriptions, place names, prices and tips are **original
GoTRVL travel-guide content** bundled in `assets/data/*.json` — the app does
not copy or scrape Google Maps listings. If you later want live Google Places
data (opening hours, ratings, reviews), integrate the Places API under
Google's terms with proper attribution and billing.

## Run it (development)

1. Install Flutter (3.35+): https://docs.flutter.dev/get-started/install
2. `flutter pub get`
3. Follow **PUBLISHING.md** steps 2–3 (Firebase + Google Maps API key) for full
   functionality. Without Firebase the app boots but auth/social features need it.
4. `flutter run`

## Build

- Android: `flutter build appbundle --release`
- iOS (Mac + Xcode): `flutter build ipa --release`

Full store submission walkthrough: **PUBLISHING.md**.
