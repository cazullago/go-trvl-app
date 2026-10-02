import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

/// Monetization data models for GoTRVL PH.
///
/// HARD POLICY: this app must NEVER handle person-to-person money transfers.
/// There are no wallets, no balances, no send-money, no cash-out, and no
/// user-to-user transfer code anywhere in these models. Monetization here is
/// limited to affiliate links (external), business listings, ads, a future
/// premium membership, and future live gifts via approved providers only.

// ---------------------------------------------------------------------------
// Business listings
// ---------------------------------------------------------------------------

enum BusinessTier {
  free,
  premium;

  static const List<String> freeFeatures = [
    'Basic business listing',
    'Appear in search and Explore',
    'Contact details and map pin',
  ];

  static const List<String> premiumFeatures = [
    'Everything in Free',
    'Enhanced profile with more photos',
    'Promotions and special offers',
    'Website and social links',
    'Featured placement options',
    'Basic analytics',
  ];
}

extension BusinessTierX on BusinessTier {
  String get label => this == BusinessTier.premium ? 'Premium' : 'Free';
}

class BusinessListing {
  final String id;
  final String ownerUid;
  final String name;
  // Allowed values: hotel, resort, restaurant, cafe, tour_operator,
  // attraction, activity, other
  final String category;
  final String description;
  final List<String> photoUrls;
  final String phone;
  final String website;
  final Map<String, String> socials;
  final String provinceId;
  final BusinessTier tier;
  final bool isFeatured;

  /// When the featured placement expires (null = not scheduled / lifetime).
  final DateTime? featuredUntil;

  /// When true, this business is a quest stop on the gamified map.
  final bool isQuestStop;

  /// QuestPlace id this business is anchored to ('' when not a quest stop).
  final String questPlaceId;

  /// Display price, free text (e.g. "₱1,500 / pax"). Never a transaction —
  /// bookings always happen on the business's external link.
  final String price;

  /// Map pin for quest-stop businesses (0,0 = not set).
  final double lat;
  final double lng;

  // Allowed values: 'pending' | 'approved' | 'rejected'
  final String status;
  final DateTime createdAt;

  const BusinessListing({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.category,
    this.description = '',
    this.photoUrls = const [],
    this.phone = '',
    this.website = '',
    this.socials = const {},
    this.provinceId = '',
    this.tier = BusinessTier.free,
    this.isFeatured = false,
    this.featuredUntil,
    this.isQuestStop = false,
    this.questPlaceId = '',
    this.price = '',
    this.lat = 0,
    this.lng = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  factory BusinessListing.fromMap(String id, Map<String, dynamic> m) =>
      BusinessListing(
        id: id,
        ownerUid: m['ownerUid'] ?? '',
        name: m['name'] ?? '',
        category: m['category'] ?? 'other',
        description: m['description'] ?? '',
        photoUrls: stringList(m['photoUrls']),
        phone: m['phone'] ?? '',
        website: m['website'] ?? '',
        socials: stringMap(m['socials']),
        provinceId: m['provinceId'] ?? '',
        tier: BusinessTier.values.firstWhere(
          (t) => t.name == m['tier'],
          orElse: () => BusinessTier.free,
        ),
        // Strict bool check: a junk value (e.g. the string "true") must
        // never promote a listing to featured.
        isFeatured: m['isFeatured'] == true,
        featuredUntil: dateTimeOfOrNull(m['featuredUntil']),
        isQuestStop: m['isQuestStop'] == true,
        questPlaceId: m['questPlaceId']?.toString() ?? '',
        price: m['price']?.toString() ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        status: m['status'] ?? 'pending',
        createdAt: dateTimeOf(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'name': name,
        'category': category,
        'description': description,
        'photoUrls': photoUrls,
        'phone': phone,
        'website': website,
        'socials': socials,
        'provinceId': provinceId,
        'tier': tier.name,
        'isFeatured': isFeatured,
        'featuredUntil':
            featuredUntil == null ? null : Timestamp.fromDate(featuredUntil!),
        'isQuestStop': isQuestStop,
        'questPlaceId': questPlaceId,
        'price': price,
        'lat': lat,
        'lng': lng,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ---------------------------------------------------------------------------
// Affiliate links
// ---------------------------------------------------------------------------

class AffiliatePartner {
  final String id;
  final String name;
  // Contains the literal token YOUR_AFFILIATE_ID plus {place} and/or
  // {destination} tokens that get replaced per link.
  final String urlTemplate;
  // Place-category keys this partner applies to, e.g. 'where_to_stay'.
  final List<String> appliesToCategories;

  const AffiliatePartner({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.appliesToCategories,
  });
}

class AffiliateLink {
  final String
      label; // "View Deal" | "Book with Partner" | "Check Availability"
  final String url;
  final String partnerName;
  // Disclosure requirement: this must ALWAYS be true so every affiliate
  // link renders with a sponsored/disclosure label.
  final bool isSponsored;

  const AffiliateLink({
    required this.label,
    required this.url,
    required this.partnerName,
    this.isSponsored = true,
  });
}

// ---------------------------------------------------------------------------
// Ads
// ---------------------------------------------------------------------------

class AdPlacement {
  final String id;
  final String slot;
  final String title;
  final String imageUrl;
  final String ctaLabel;
  final String targetUrl;
  final bool isHouseAd;

  static const slotFeed = 'feed_inline';
  static const slotMarketplace = 'marketplace_banner';
  static const slotExplore = 'explore_banner';

  const AdPlacement({
    required this.id,
    required this.slot,
    required this.title,
    this.imageUrl = '',
    this.ctaLabel = 'Learn more',
    this.targetUrl = '',
    this.isHouseAd = false,
  });
}

// ---------------------------------------------------------------------------
// Premium membership (future)
// ---------------------------------------------------------------------------

enum PremiumFeature {
  advancedPlanner,
  offlineGuides,
  exclusiveDeals,
  unlimitedTrips,
  advancedMemories,
  premiumItineraries,
}

extension PremiumFeatureX on PremiumFeature {
  String get label {
    switch (this) {
      case PremiumFeature.advancedPlanner:
        return 'Advanced Trip Planner';
      case PremiumFeature.offlineGuides:
        return 'Offline Guides';
      case PremiumFeature.exclusiveDeals:
        return 'Exclusive Deals';
      case PremiumFeature.unlimitedTrips:
        return 'Unlimited Trips';
      case PremiumFeature.advancedMemories:
        return 'Advanced Memories';
      case PremiumFeature.premiumItineraries:
        return 'Premium Itineraries';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.advancedPlanner:
        return 'Build multi-day itineraries with smart day-by-day scheduling.';
      case PremiumFeature.offlineGuides:
        return 'Download destination guides for use without internet.';
      case PremiumFeature.exclusiveDeals:
        return 'Unlock member-only discounts from partner businesses.';
      case PremiumFeature.unlimitedTrips:
        return 'Create as many trip plans as you want, with no limits.';
      case PremiumFeature.advancedMemories:
        return 'Extra photo storage plus auto-generated travel recaps.';
      case PremiumFeature.premiumItineraries:
        return 'Curated expert itineraries for top Philippine destinations.';
    }
  }
}

// ---------------------------------------------------------------------------
// Live streaming
// ---------------------------------------------------------------------------

class LiveStream {
  final String id;
  final String creatorUid;
  final String creatorName;
  final String creatorPhoto;
  final String title;
  final String description;
  // Allowed values: 'destination_tour' | 'food_trip' | 'local_experience' |
  // 'travel_tips' | 'hotel_tour' | 'ask_a_local'
  final String category;
  // Allowed values: 'scheduled' | 'live' | 'ended'
  final String status;
  final DateTime? scheduledAt;
  final int viewerCount;

  const LiveStream({
    required this.id,
    required this.creatorUid,
    required this.creatorName,
    this.creatorPhoto = '',
    required this.title,
    this.description = '',
    this.category = 'destination_tour',
    this.status = 'scheduled',
    this.scheduledAt,
    this.viewerCount = 0,
  });

  factory LiveStream.fromMap(String id, Map<String, dynamic> m) => LiveStream(
        id: id,
        creatorUid: m['creatorUid'] ?? '',
        creatorName: m['creatorName'] ?? '',
        creatorPhoto: m['creatorPhoto'] ?? '',
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        category: m['category'] ?? 'destination_tour',
        status: m['status'] ?? 'scheduled',
        scheduledAt: dateTimeOfOrNull(m['scheduledAt']),
        viewerCount: (m['viewerCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'creatorUid': creatorUid,
        'creatorName': creatorName,
        'creatorPhoto': creatorPhoto,
        'title': title,
        'description': description,
        'category': category,
        'status': status,
        'scheduledAt':
            scheduledAt == null ? null : Timestamp.fromDate(scheduledAt!),
        'viewerCount': viewerCount,
      };
}

class LiveChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime sentAt;

  const LiveChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  factory LiveChatMessage.fromMap(String id, Map<String, dynamic> m) =>
      LiveChatMessage(
        id: id,
        senderUid: m['senderUid'] ?? '',
        senderName: m['senderName'] ?? '',
        text: m['text'] ?? '',
        sentAt: dateTimeOf(m['sentAt']),
      );

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'senderName': senderName,
        'text': text,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}

// MODEL ONLY: no purchase flow exists for virtual gifts. Gifts are disabled
// until a compliant payment provider is integrated. Per the app-wide hard
// policy, gifts must never move money person-to-person; any future gift flow
// goes through an approved provider only.
class VirtualGift {
  final String id;
  final String name;
  final String icon; // emoji
  final int coinPrice;

  const VirtualGift({
    required this.id,
    required this.name,
    required this.icon,
    required this.coinPrice,
  });

  static const List<VirtualGift> samples = [
    VirtualGift(id: 'palm', name: 'Palm Tree', icon: '🌴', coinPrice: 10),
    VirtualGift(id: 'sunset', name: 'Sunset', icon: '🌅', coinPrice: 25),
    VirtualGift(id: 'island', name: 'Island', icon: '🏝️', coinPrice: 50),
    VirtualGift(id: 'jeepney', name: 'Jeepney', icon: '🛺', coinPrice: 100),
  ];
}
