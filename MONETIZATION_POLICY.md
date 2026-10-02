# GoTRVL PH — Monetization Policy

This document is the source of truth for what GoTRVL PH may and may not do
with money. It binds every future change to the app's monetization code.
If a proposed feature conflicts with this policy, the feature does not ship.

Last updated: 2026-09-30 (freemium map + premium tiers).

## 1. ABSOLUTE RULE: NO PERSON-TO-PERSON MONEY TRANSFERS

GoTRVL PH is a travel discovery, planning, community, creator LIVE, and
travel-business marketplace app. It is NOT a money-transfer service.

The app must NEVER include, and no future change may introduce:

- User wallets or stored balances for sending money between users
- "Send money" buttons or flows of any kind
- User-to-user transfers, informal cash balances, or cash-out of
  user-to-user transfers
- Any feature that lets one user pay another user directly through the app

This applies to the core app AND to the LIVE feature: if virtual gifts or
tipping are ever added, users purchase virtual items through the app's
approved payment system (e.g. Google Play Billing / App Store In-App
Purchase), and creator payouts are handled through a compliant
payout/payment provider. There is deliberately no user-to-user wallet
in the architecture, so this cannot happen by accident.

## 2. WHAT STAYS FREE — FOREVER

These are free for every traveler and must never be paywalled:

- Browsing the map of the Philippines and the Discover sheet
- Places near the user (GPS) and places the user has already visited
- Destination overviews for unlocked places
- Trip planner (basic)
- Travel memories and profile (posting memories is always free)
- Save / favorite places
- Travel social feed, stories, invitations
- Travel buddy matching and messaging (basic)
- Gamification: points, levels, passport stamps, quests

## 3. MAP UNLOCK MODEL (freemium)

The map is browsable by everyone, but a place's full detail unlocks by one
of these paths:

1. **Premium traveler** — the whole map is open.
2. **Nearby (GPS)** — places around the user open automatically.
3. **Visited** — a place the user has been to stays open forever.
4. **Engagement tasks** — each completed task opens one place (send
   invitation links, follow people, go live — tasks that keep the app
   active).
5. **Per-place purchase** — ~₱10–₱20 per place via store billing.

Locked places show a clear upsell (never a dead end): the sheet explains
the four ways to open it. Prices are illustrative and set in the store
consoles, never hard-coded as fact in UI copy.

## 4. APPROVED REVENUE STREAMS

### 4a. Traveler premium (~₱100/month, via Play/App Store billing)
- Whole map unlocked.
- Matching: see exactly who viewed or liked you (free users get a teaser
  notification — photo only, name hidden).
- Cancel anytime; premium status is stored on the user doc with an expiry.

### 4b. Per-place unlocks (~₱10–₱20, via Play/App Store billing)
One-time purchase opening a single place permanently for that user.

### 4c. Featured marketplace listings (paid, via Play/App Store billing)
Businesses may pay to pin their listing at the TOP of marketplace results.
ALL paid placements MUST be clearly labeled "Featured" in the UI.

### 4d. Premium for Business (~₱100, via Play/App Store billing)
- Pinned listing on top (Featured label).
- The shop added as a QUEST STOP on the map: travelers earn quest points
  by visiting, which drives foot traffic to the business.

### 4e. Business listings (free basic tier)
Philippine travel businesses may create a BASIC listing for free. A basic
listing is never forced to pay.

### 4f. Travel affiliate links
Hotels, resorts, activities, tours with "View Deal" / "Book with Partner"
/ "Check Availability" buttons. Tapping opens the EXTERNAL partner
(authorized booking/payment provider) in the system browser — the
transaction happens there; GoTRVL PH never holds booking money. Every
affiliate link MUST be disclosed ("Affiliate link — we may earn a
commission"). Driven by `lib/config/affiliate_config.dart`; dead buttons
must never be shown.

### 4g. Advertising
Travel-related ads in defined slots (`feed_inline`, `marketplace_banner`).
MUST be visually distinct: dashed border + "Ad"/"Sponsored" tag.

### 4h. LIVE virtual gifts (future)
LIVE streaming itself is free. Gifts are bought via the approved in-app
payment system; creator payouts via a compliant provider. No P2P.

## 5. BOOKING MONEY RULE

Whenever a traveler books something, GoTRVL PH sends them to the
appropriate authorized booking/payment provider instead of holding the
customer's booking money itself. Monetization must feel like a travel
app, NOT a banking app.

## 6. PURCHASE RULES

- ALL digital purchases (premium, unlocks, featured, business premium,
  gifts) go through Google Play Billing / App Store In-App Purchase.
- No side-channel payments, no manual transfers, no "send to GCash"
  flows inside the app.
- Test builds may include a clearly-marked DEBUG bypass
  (`BillingService.debugBypass`) that labels itself "TEST MODE — no real
  charge". It must be OFF in any store release.

## 7. ARCHITECTURE NOTES

- `lib/models/monetization_models.dart` — BusinessListing (+isFeatured,
  isQuestStop), AffiliatePartner/Link, AdPlacement, PremiumFeature,
  LiveStream, LiveChatMessage, VirtualGift (model only until providers
  are connected).
- `lib/config/affiliate_config.dart` — master switch + partner templates.
- `lib/services/` — affiliate_service, business_service, ad_service,
  billing_service (store billing + debug bypass), premium helpers,
  live_service, live_video_provider (abstract + stub; real video SDK
  integrates at the marked TODO), game_service (points/levels/stamps).
- Firestore: `businesses`, `live_streams`, `live_streams/{id}/chat`,
  `memories`, `posts`, `invitations`, `stories`, `conversations`,
  `notifications` (see firestore.rules; deploy + test in the emulator
  before production).
- Revenue priority order: traveler premium, business premium + featured
  listings, per-place unlocks, affiliate commissions, advertising,
  future LIVE virtual gifts.
