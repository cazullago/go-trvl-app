import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps a JSON list through [fromJson], skipping entries that are not
/// maps or that the parser rejects. Never throws, so one malformed place
/// or city never sinks its whole destination or province.
List<T> modelList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return [];
  final out = <T>[];
  for (final e in value) {
    if (e is! Map<String, dynamic>) continue;
    try {
      out.add(fromJson(e));
    } catch (_) {}
  }
  return out;
}

/// Points awarded per category when a place is marked done.
/// Safe-parsing helpers: Firestore and bundled JSON can both carry
/// malformed fields (wrong types, junk entries). These degrade gracefully
/// instead of throwing, so one bad field never crashes a whole screen.

/// Returns the String elements of [value], dropping anything that is not
/// a String. Never throws, unlike `List.cast<String>()`.
List<String> stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

/// Parses an ISO-8601 date string or a Firestore [Timestamp], falling back
/// to now for anything else (null, wrong type, unparsable). Never throws,
/// unlike `DateTime.parse` or a blind `as Timestamp?` cast.
DateTime dateTimeOf(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

/// Nullable variant of [dateTimeOf]: returns null when [value] is not a
/// parseable date or Timestamp. Never throws.
DateTime? dateTimeOfOrNull(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Returns the String->String entries of [value], dropping anything else.
/// Never throws.
Map<String, String> stringMap(Object? value) {
  if (value is! Map) return const {};
  final out = <String, String>{};
  for (final e in value.entries) {
    if (e.key is String && e.value is String) {
      out[e.key as String] = e.value as String;
    }
  }
  return out;
}

const Map<String, int> categoryPoints = {
  'where_to_go': 200,
  'things_to_do': 150,
  'where_to_eat': 100,
  'where_to_stay': 50,
  'where_to_buy': 50,
  'how_to_get_around': 20,
};

class TransportOption {
  final String type;
  final String useCase;
  final String priceRange;
  final String notes;
  TransportOption(
      {required this.type,
      required this.useCase,
      required this.priceRange,
      required this.notes});
  factory TransportOption.fromJson(Map<String, dynamic> j) => TransportOption(
        type: j['type'] ?? '',
        useCase: j['useCase'] ?? '',
        priceRange: j['priceRange'] ?? '',
        notes: j['notes'] ?? '',
      );
}

class Place {
  final String id;
  final String name;
  final String category; // where_to_go | things_to_do | ...
  final String placeType;
  final String description;
  final String priceRange;
  final String area;
  final String bestTime;
  final double lat;
  final double lng;

  Place(
      {required this.id,
      required this.name,
      required this.category,
      required this.placeType,
      required this.description,
      required this.priceRange,
      required this.area,
      required this.bestTime,
      required this.lat,
      required this.lng});

  int get points => categoryPoints[category] ?? 0;

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? 'where_to_go',
        placeType: j['placeType'] ?? '',
        description: j['description'] ?? '',
        priceRange: j['priceRange'] ?? '',
        area: j['area'] ?? '',
        bestTime: j['bestTime'] ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );
}

class Destination {
  final String id;
  final String name;
  final String region;
  final String province;
  final String provinceId;
  final String tagline;
  final String description;
  final String whyPopular;
  final String bestTime;
  final String howToGetThere;
  final double centerLat;
  final double centerLng;
  final List<Place> places;
  final List<TransportOption> transport;

  Destination(
      {required this.id,
      required this.name,
      required this.region,
      required this.province,
      this.provinceId = '',
      required this.tagline,
      required this.description,
      required this.whyPopular,
      required this.bestTime,
      required this.howToGetThere,
      required this.centerLat,
      required this.centerLng,
      required this.places,
      required this.transport});

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        region: j['region'] ?? '',
        province: j['province'] ?? '',
        provinceId: j['provinceId'] ?? '',
        tagline: j['tagline'] ?? '',
        description: j['description'] ?? '',
        whyPopular: j['whyPopular'] ?? '',
        bestTime: j['bestTime'] ?? '',
        howToGetThere: j['howToGetThere'] ?? '',
        centerLat: (j['centerLat'] as num?)?.toDouble() ?? 0,
        centerLng: (j['centerLng'] as num?)?.toDouble() ?? 0,
        places: modelList(j['places'], Place.fromJson),
        transport: modelList(j['transport'], TransportOption.fromJson),
      );

  List<Place> placesIn(String category) =>
      places.where((p) => p.category == category).toList();
}

/// A city or municipality inside a province (the province's "where to go").
class ProvinceCity {
  final String name;
  final String type; // "city" | "municipality"
  final double lat;
  final double lng;

  const ProvinceCity(
      {required this.name,
      required this.type,
      required this.lat,
      required this.lng});

  factory ProvinceCity.fromJson(Map<String, dynamic> j) => ProvinceCity(
        name: j['name'] ?? '',
        type: j['type'] ?? 'municipality',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );

  bool get isCity => type == 'city';
}

/// A Philippine province (82 provinces + Metro Manila = 83 entries).
class Province {
  final String id;
  final String name;
  final String region; // Luzon | Visayas | Mindanao
  final String capital;
  final String tagline;
  final String description;
  final List<String> tags;
  final double lat;
  final double lng;
  final List<ProvinceCity> cities;

  Province(
      {required this.id,
      required this.name,
      required this.region,
      required this.capital,
      required this.tagline,
      required this.description,
      required this.tags,
      required this.lat,
      required this.lng,
      this.cities = const []});

  factory Province.fromJson(Map<String, dynamic> j) => Province(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        region: j['region'] ?? '',
        capital: j['capital'] ?? '',
        tagline: j['tagline'] ?? '',
        description: j['description'] ?? '',
        tags: stringList(j['tags']),
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        cities: modelList(j['cities'], ProvinceCity.fromJson),
      );
}

/// Gamification levels shown on the passport profile.
///
/// The ladder is points-based (1–9). The special 10th level, Alamat ('✨'),
/// is never reached by points: it is granted only when the user has
/// collected every stamp ([hasAllStamps]).
class TravelLevel {
  final int minPoints;
  final String name;
  final String emoji;
  const TravelLevel(this.minPoints, this.name, this.emoji);

  static const all = [
    TravelLevel(0, 'New Traveler', '🌱'),
    TravelLevel(500, 'Explorer', '🧭'),
    TravelLevel(1500, 'Adventurer', '🎒'),
    TravelLevel(3000, 'Wanderer', '🗺️'),
    TravelLevel(5500, 'Voyager', '⛵'),
    TravelLevel(9000, 'Island Hopper', '🏝️'),
    TravelLevel(14000, 'Trailblazer', '🔥'),
    TravelLevel(21000, 'Expedition Leader', '🏔️'),
    TravelLevel(30000, 'Philippine Legend', '🇵🇭'),
  ];

  /// Special 10th level: granted only when every stamp is collected.
  static const alamat = TravelLevel(0, 'Alamat', '✨');

  static TravelLevel of(int points, {bool hasAllStamps = false}) {
    if (hasAllStamps) return alamat;
    TravelLevel current = all.first;
    for (final l in all) {
      if (points >= l.minPoints) current = l;
    }
    return current;
  }

  /// 1..9 for the points ladder, 10 for Alamat.
  int get levelNumber {
    if (this == alamat) return 10;
    return all.indexOf(this) + 1;
  }

  /// Points needed to reach the next level (null when maxed).
  static int? nextThreshold(int points) {
    for (final l in all) {
      if (l.minPoints > points) return l.minPoints;
    }
    return null;
  }

  /// 0.0..1.0 progress *within* the traveler's current level, so a fresh
  /// level-up reads 0% and the bar fills toward the next threshold.
  /// Alamat (all stamps collected) is always complete at 1.0.
  static double progressInLevel(int points, {bool hasAllStamps = false}) {
    if (hasAllStamps) return 1.0;
    final next = nextThreshold(points);
    if (next == null) return 1.0;
    final floor = of(points).minPoints;
    return ((points - floor) / (next - floor)).clamp(0.0, 1.0);
  }
}

/// A gamified quest pin on the map: a place tied to a province and a
/// destination, with a filter bucket ('where_to_go' | 'things_to_do' |
/// 'where_to_eat') that decides its default point value.
class QuestPlace {
  final String id;
  final String name;
  final String province;
  final String destination;
  final String filter; // where_to_go | things_to_do | where_to_eat
  final double lat;
  final double lng;
  final String address;
  final String blurb;
  final int points;

  const QuestPlace({
    required this.id,
    required this.name,
    required this.province,
    required this.destination,
    required this.filter,
    required this.lat,
    required this.lng,
    this.address = '',
    this.blurb = '',
    required this.points,
  });

  /// Default point award per filter bucket.
  static int defaultPointsFor(String filter) {
    switch (filter) {
      case 'where_to_go':
        return 300;
      case 'things_to_do':
        return 200;
      case 'where_to_eat':
        return 150;
      default:
        return 200;
    }
  }

  static int _clampPoints(int p) => p.clamp(100, 1000);

  /// Safe parse: never throws. Unknown/missing fields fall back to sane
  /// defaults; points default to the filter bucket, clamped to 100..1000.
  factory QuestPlace.fromJson(Map<String, dynamic> j) {
    final filter = (j['filter'] ?? 'where_to_go').toString();
    final rawPoints =
        (j['points'] as num?)?.toInt() ?? defaultPointsFor(filter);
    return QuestPlace(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      province: j['province']?.toString() ?? '',
      destination: j['destination']?.toString() ?? '',
      filter: filter,
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      address: j['address']?.toString() ?? '',
      blurb: j['blurb']?.toString() ?? '',
      points: _clampPoints(rawPoints),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'province': province,
        'destination': destination,
        'filter': filter,
        'lat': lat,
        'lng': lng,
        'address': address,
        'blurb': blurb,
        'points': points,
      };
}

/// A "quest memory": a photo moment a user pins on a quest place after
/// completing it. Memories are public or only-me, and show in the feed
/// and on the user's profile.
class Memory {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String placeId;
  final String placeName;
  final String caption;
  final List<String> photoUrls;
  final String privacy; // 'public' | 'only_me'
  final DateTime createdAt;

  const Memory({
    required this.id,
    required this.uid,
    required this.userName,
    this.userPhoto = '',
    required this.placeId,
    required this.placeName,
    this.caption = '',
    this.photoUrls = const [],
    this.privacy = 'public',
    required this.createdAt,
  });

  bool get isPublic => privacy == 'public';

  factory Memory.fromMap(String id, Map<String, dynamic> m) => Memory(
        id: id,
        uid: m['uid']?.toString() ?? '',
        userName: m['userName']?.toString() ?? '',
        userPhoto: m['userPhoto']?.toString() ?? '',
        placeId: m['placeId']?.toString() ?? '',
        placeName: m['placeName']?.toString() ?? '',
        caption: m['caption']?.toString() ?? '',
        photoUrls: stringList(m['photoUrls']),
        privacy: m['privacy']?.toString() == 'only_me' ? 'only_me' : 'public',
        createdAt: dateTimeOf(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'placeId': placeId,
        'placeName': placeName,
        'caption': caption,
        'photoUrls': photoUrls,
        'privacy': privacy,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A travel invite scoped to a location. Viewers can tap "I'm interested"
/// and the app counts how many will go.
class TravelInvitation {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String what;
  final String where;
  final String who;
  final String time;
  final String locationTag;
  final double lat;
  final double lng;
  final List<String> interestedUids;
  final DateTime createdAt;

  const TravelInvitation({
    required this.id,
    required this.uid,
    required this.userName,
    this.userPhoto = '',
    this.what = '',
    this.where = '',
    this.who = '',
    this.time = '',
    this.locationTag = '',
    this.lat = 0,
    this.lng = 0,
    this.interestedUids = const [],
    required this.createdAt,
  });

  int get interestedCount => interestedUids.length;

  factory TravelInvitation.fromMap(String id, Map<String, dynamic> m) =>
      TravelInvitation(
        id: id,
        uid: m['uid']?.toString() ?? '',
        userName: m['userName']?.toString() ?? '',
        userPhoto: m['userPhoto']?.toString() ?? '',
        what: m['what']?.toString() ?? '',
        where: m['where']?.toString() ?? '',
        who: m['who']?.toString() ?? '',
        time: m['time']?.toString() ?? '',
        locationTag: m['locationTag']?.toString() ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        interestedUids: stringList(m['interestedUids']),
        createdAt: dateTimeOf(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'what': what,
        'where': where,
        'who': who,
        'time': time,
        'locationTag': locationTag,
        'lat': lat,
        'lng': lng,
        'interestedUids': interestedUids,
        'createdAt': createdAt.toIso8601String(),
      };
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final int age;
  final String location;
  final String bio;
  final String photoUrl;
  final String coverUrl;
  final int points;
  final int followers;
  final int following;
  final List<String> donePlaceIds;

  /// Uids this user has blocked. Only the owner can write it (firestore.rules).
  /// Blocked users are filtered out of matching candidates and message lists.
  final List<String> blockedUids;

  /// Set by admins only (Firestore rules block users from changing it).
  /// Suspended users are signed out and blocked at sign-in.
  final bool suspended;

  /// Stamp ids ('stamp:<questPlaceId>') the user has collected.
  final List<String> stamps;

  /// Quest place ids unlocked (beyond radius/done-place rules).
  final List<String> unlockedPlaceIds;

  /// Paid membership flag, set by BillingService on purchase.
  final bool premiumTraveler;

  /// When the premium membership expires (null = never set / lifetime).
  final DateTime? premiumExpiry;

  final String gender;
  final bool onboardingDone;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.age = 0,
    this.location = '',
    this.bio = '',
    this.photoUrl = '',
    this.coverUrl = '',
    this.points = 0,
    this.followers = 0,
    this.following = 0,
    this.donePlaceIds = const [],
    this.blockedUids = const [],
    this.suspended = false,
    this.stamps = const [],
    this.unlockedPlaceIds = const [],
    this.premiumTraveler = false,
    this.premiumExpiry,
    this.gender = '',
    this.onboardingDone = false,
  });

  TravelLevel get level => TravelLevel.of(points);

  /// True when the membership flag is set and has not expired.
  bool get isPremiumActive {
    if (!premiumTraveler) return false;
    if (premiumExpiry == null) return true;
    return DateTime.now().isBefore(premiumExpiry!);
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        age: (m['age'] as num?)?.toInt() ?? 0,
        location: m['location'] ?? '',
        bio: m['bio'] ?? '',
        photoUrl: m['photoUrl'] ?? '',
        coverUrl: m['coverUrl'] ?? '',
        points: (m['points'] as num?)?.toInt() ?? 0,
        followers: (m['followers'] as num?)?.toInt() ?? 0,
        following: (m['following'] as num?)?.toInt() ?? 0,
        donePlaceIds: stringList(m['donePlaceIds']),
        blockedUids: ((m['blockedUids'] as List?) ?? []).cast<String>(),
        suspended: m['suspended'] == true,
        stamps: stringList(m['stamps']),
        unlockedPlaceIds: stringList(m['unlockedPlaceIds']),
        premiumTraveler: m['premiumTraveler'] == true,
        premiumExpiry: dateTimeOfOrNull(m['premiumExpiry']),
        gender: m['gender']?.toString() ?? '',
        onboardingDone: m['onboardingDone'] == true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'age': age,
        'location': location,
        'bio': bio,
        'photoUrl': photoUrl,
        'coverUrl': coverUrl,
        'points': points,
        'followers': followers,
        'following': following,
        'donePlaceIds': donePlaceIds,
        'blockedUids': blockedUids,
        'stamps': stamps,
        'unlockedPlaceIds': unlockedPlaceIds,
        'premiumTraveler': premiumTraveler,
        'premiumExpiry':
            premiumExpiry == null ? null : premiumExpiry!.toIso8601String(),
        'gender': gender,
        'onboardingDone': onboardingDone,
      };
}

class Post {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String imageUrl;
  final String caption;
  final String locationTag;
  final int likes;
  final List<String> likedBy;
  final DateTime createdAt;
  final int commentCount;

  /// Author's points at post time, for the LevelBadge on the card.
  /// Older docs lack it: fromMap falls back to 0.
  final int authorPoints;

  /// All photo urls for multi-photo posts. fromMap falls back to
  /// [imageUrl] when the list is absent.
  final List<String> imageUrls;

  /// Set when this post was created alongside a travel invitation, so
  /// the card can deep-link to the invite.
  final String invitationId;

  Post({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.imageUrl,
    required this.caption,
    required this.locationTag,
    this.likes = 0,
    this.likedBy = const [],
    required this.createdAt,
    this.commentCount = 0,
    this.authorPoints = 0,
    this.imageUrls = const [],
    this.invitationId = '',
  });

  /// Photos to render: the multi-photo list when present, else the
  /// legacy single [imageUrl].
  List<String> get photos {
    if (imageUrls.isNotEmpty) return imageUrls;
    return imageUrl.isEmpty ? const [] : [imageUrl];
  }

  factory Post.fromMap(String id, Map<String, dynamic> m) {
    final multi = stringList(m['imageUrls']);
    final single = (m['imageUrl'] ?? '').toString();
    return Post(
      id: id,
      uid: m['uid'] ?? '',
      userName: m['userName'] ?? '',
      userPhoto: m['userPhoto'] ?? '',
      imageUrl: single,
      caption: m['caption'] ?? '',
      locationTag: m['locationTag'] ?? '',
      likes: (m['likes'] as num?)?.toInt() ?? 0,
      likedBy: stringList(m['likedBy']),
      createdAt: dateTimeOf(m['createdAt']),
      commentCount: (m['commentCount'] as num?)?.toInt() ?? 0,
      authorPoints: (m['authorPoints'] as num?)?.toInt() ?? 0,
      imageUrls:
          multi.isNotEmpty ? multi : (single.isEmpty ? const [] : [single]),
      invitationId: (m['invitationId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'imageUrl': imageUrl,
        'caption': caption,
        'locationTag': locationTag,
        'likes': likes,
        'likedBy': likedBy,
        'createdAt': createdAt.toIso8601String(),
        'commentCount': commentCount,
        'authorPoints': authorPoints,
        'imageUrls': imageUrls,
        'invitationId': invitationId,
      };
}

class PostComment {
  final String id;
  final String uid;
  final String userName;
  final String text;
  final DateTime createdAt;
  PostComment(
      {required this.id,
      required this.uid,
      required this.userName,
      required this.text,
      required this.createdAt});
  factory PostComment.fromMap(String id, Map<String, dynamic> m) => PostComment(
        id: id,
        uid: m['uid'] ?? '',
        userName: m['userName'] ?? '',
        text: m['text'] ?? '',
        createdAt: dateTimeOf(m['createdAt']),
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  ChatMessage(
      {required this.id,
      required this.senderId,
      required this.text,
      required this.createdAt});
  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        senderId: m['senderId'] ?? '',
        text: m['text'] ?? '',
        createdAt: dateTimeOf(m['createdAt']),
      );
  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': DateTime.now().toIso8601String(),
      };
}

class Conversation {
  final String id;
  final List<String> memberIds;
  final String otherUid;
  final String otherName;
  final String otherPhoto;
  final String lastMessage;
  final DateTime updatedAt;

  /// Group-chat support and the messages-inbox section this conversation
  /// belongs to: 'buddy' | 'marketplace' | 'friend' | 'request'.
  final bool isGroup;
  final String groupName;
  final String photoUrl;
  final String kind;

  Conversation({
    required this.id,
    required this.memberIds,
    this.otherUid = '',
    required this.otherName,
    required this.otherPhoto,
    required this.lastMessage,
    required this.updatedAt,
    this.isGroup = false,
    this.groupName = '',
    this.photoUrl = '',
    this.kind = 'buddy',
  });
}

class BuddyCard {
  final String uid;
  final String name;
  final int age;
  final String location;
  final String photoUrl;
  final String bio;
  final List<String> interests;

  /// Gamification + matching extras: points drive the badge, distanceKm
  /// (user's location → card's location) drives "near you" sorting.
  final int points;
  final double distanceKm;

  BuddyCard(
      {required this.uid,
      required this.name,
      required this.age,
      required this.location,
      required this.photoUrl,
      required this.bio,
      required this.interests,
      this.points = 0,
      this.distanceKm = 0});
}

/// A 24-hour story: photo + caption, shown in the feed stories row and on
/// the author's profile (Facebook-style). Collection: stories/{storyId}.
class Story {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String photoUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;

  const Story({
    required this.id,
    required this.uid,
    required this.userName,
    this.userPhoto = '',
    required this.photoUrl,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Story.fromMap(String id, Map<String, dynamic> m) => Story(
        id: id,
        uid: m['uid']?.toString() ?? '',
        userName: m['userName']?.toString() ?? '',
        userPhoto: m['userPhoto']?.toString() ?? '',
        photoUrl: m['photoUrl']?.toString() ?? '',
        caption: m['caption']?.toString() ?? '',
        createdAt: dateTimeOf(m['createdAt']),
        expiresAt: dateTimeOf(m['expiresAt']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'photoUrl': photoUrl,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// An inbox notification: likes, comments, follows, match teasers, and
/// invitation alerts. Collection: users/{uid}/notifications/{notifId}.
///
/// Match-teaser privacy: notifications of type 'view' or 'like' that come
/// from matching render as "Someone viewed/liked you" (photo only) unless
/// the viewer is a premium traveler.
class AppNotification {
  /// 'like' | 'comment' | 'follow' | 'view' | 'match' | 'invitation'
  final String id;
  final String type;
  final String actorUid;
  final String actorName;
  final String actorPhoto;
  final String title;
  final String body;
  final String postId;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    this.actorUid = '',
    this.actorName = '',
    this.actorPhoto = '',
    this.title = '',
    this.body = '',
    this.postId = '',
    required this.createdAt,
    this.read = false,
  });

  /// True for matching-origin teasers, which hide the actor's name from
  /// non-premium viewers.
  bool get isMatchTeaser => type == 'view' || type == 'like';

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) =>
      AppNotification(
        id: id,
        type: m['type']?.toString() ?? '',
        actorUid: m['actorUid']?.toString() ?? '',
        actorName: m['actorName']?.toString() ?? '',
        actorPhoto: m['actorPhoto']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        body: m['body']?.toString() ?? '',
        postId: m['postId']?.toString() ?? '',
        createdAt: dateTimeOf(m['createdAt']),
        read: m['read'] == true,
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorPhoto': actorPhoto,
        'title': title,
        'body': body,
        'postId': postId,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };
}

/// Lightweight geo alert written alongside every travel invitation.
///
/// Cloud-Function-free fan-out: instead of a backend function matching
/// invitations to nearby users, each invitation writes one alert doc keyed
/// by its coarse location string ([geoKey], normalized from the invitation's
/// WHERE field). NotificationsScreen queries recent alerts and keeps the
/// ones whose [geoKey] matches the viewer's own location text (either
/// direction, case-insensitive). Coarse and approximate by design: it
/// surfaces "island hopping near Siargao" to someone whose profile says
/// Siargao, without any server code or precise tracking.
class InvitationAlert {
  final String id;
  final String invitationId;
  final String uid;
  final String userName;
  final String what;
  final String where;
  final String geoKey;
  final DateTime createdAt;

  const InvitationAlert({
    required this.id,
    required this.invitationId,
    this.uid = '',
    this.userName = '',
    this.what = '',
    this.where = '',
    this.geoKey = '',
    required this.createdAt,
  });

  factory InvitationAlert.fromMap(String id, Map<String, dynamic> m) =>
      InvitationAlert(
        id: id,
        invitationId: m['invitationId']?.toString() ?? '',
        uid: m['uid']?.toString() ?? '',
        userName: m['userName']?.toString() ?? '',
        what: m['what']?.toString() ?? '',
        where: m['where']?.toString() ?? '',
        geoKey: m['geoKey']?.toString() ?? '',
        createdAt: dateTimeOf(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'invitationId': invitationId,
        'uid': uid,
        'userName': userName,
        'what': what,
        'where': where,
        'geoKey': geoKey,
        'createdAt': createdAt.toIso8601String(),
      };
}
