import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/models.dart';

/// All Firestore / Storage access. Collections:
/// users/{uid}, users/{uid}/donePlaces/{placeId},
/// posts/{postId}, posts/{postId}/comments/{commentId},
/// matches/{matchId}, conversations/{convId}/messages/{msgId}
class DatabaseService {
  // Lazily resolved so constructing this class never crashes when Firebase
  // has not been configured yet (methods only run while signed in).
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // ---------- Gamification: mark a place done ----------
  /// Marks a place done for uid, awards category points. Returns points earned
  /// (0 when already done).
  Future<int> markPlaceDone(String uid, Place place) async {
    final ref = _db.collection('users').doc(uid);
    final doneRef = ref.collection('donePlaces').doc(place.id);
    return _db.runTransaction((tx) async {
      final doneSnap = await tx.get(doneRef);
      if (doneSnap.exists) return 0;
      final userSnap = await tx.get(ref);
      final current = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;
      final earned = place.points;
      tx.set(doneRef, {
        'placeId': place.id,
        'name': place.name,
        'category': place.category,
        'points': earned,
        'doneAt': FieldValue.serverTimestamp(),
      });
      final doneIds = stringList(userSnap.data()?['donePlaceIds']);
      if (!doneIds.contains(place.id)) doneIds.add(place.id);
      tx.update(ref, {'points': current + earned, 'donePlaceIds': doneIds});
      return earned;
    });
  }

  Future<Set<String>> donePlaceIds(String uid) async {
    final snap =
        await _db.collection('users').doc(uid).collection('donePlaces').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<List<AppUser>> leaderboard({int limit = 50}) async {
    final snap = await _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  // ---------- Posts / feed ----------
  Stream<List<Post>> postStream() => _db
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => s.docs.map((d) => Post.fromMap(d.id, d.data())).toList());

  Stream<List<Post>> userPosts(String uid) => _db
      .collection('posts')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Post.fromMap(d.id, d.data())).toList());

  Future<String> uploadImage(File file, String path) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> createPost(Post post) async {
    await _db.collection('posts').add(post.toMap());
  }

  Future<void> toggleLike(String postId, String uid, bool liked) async {
    final ref = _db.collection('posts').doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final likedBy = stringList(snap.data()?['likedBy']);
      if (liked) {
        likedBy.remove(uid);
      } else {
        if (!likedBy.contains(uid)) likedBy.add(uid);
      }
      tx.update(ref, {'likedBy': likedBy, 'likes': likedBy.length});
    });
  }

  Stream<List<PostComment>> commentStream(String postId) => _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => PostComment.fromMap(d.id, d.data())).toList());

  Future<void> addComment(String postId, PostComment c) async {
    final postRef = _db.collection('posts').doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final count = (snap.data()?['commentCount'] as num?)?.toInt() ?? 0;
      tx.set(postRef.collection('comments').doc(), {
        'uid': c.uid,
        'userName': c.userName,
        'text': c.text,
        'createdAt': DateTime.now().toIso8601String(),
      });
      tx.update(postRef, {'commentCount': count + 1});
    });
  }

  // ---------- Blocking (Apple guideline 1.2) ----------
  /// Uids the user has blocked (the `blockedUids` array on their user doc).
  Future<Set<String>> blockedUids(String me) async {
    final doc = await _db.collection('users').doc(me).get();
    final list = (doc.data()?['blockedUids'] as List?) ?? const [];
    return list.cast<String>().toSet();
  }

  /// Uids of users who blocked [me] (used to keep them out of my deck too).
  Future<Set<String>> blockedByMe(String me) async {
    final snap = await _db
        .collection('users')
        .where('blockedUids', arrayContains: me)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Every uid hidden from [me]'s feed in either block direction: users
  /// [me] blocked plus users who blocked [me]. Never throws: on failure
  /// the feed simply shows everything (fail-open, not fail-empty).
  Future<Set<String>> blockedEitherDirection(String me) async {
    try {
      final results = await Future.wait([blockedUids(me), blockedByMe(me)]);
      return {...results[0], ...results[1]};
    } catch (_) {
      return <String>{};
    }
  }

  // ---------- Matching ----------
  /// Record a right-swipe. Returns true when it becomes a mutual match.
  ///
  /// Runs as one transaction so two users swiping at the same moment
  /// cannot miss the match: the read of their like and the writes happen
  /// atomically, and Firestore retries the transaction on contention.
  Future<bool> swipeRight(String me, String them) async {
    final theirDoc =
        _db.collection('users').doc(them).collection('likesGiven').doc(me);
    final myDoc =
        _db.collection('users').doc(me).collection('likesGiven').doc(them);
    final matched = await _db.runTransaction((tx) async {
      final theirSnap = await tx.get(theirDoc);
      final theyLikeMe = theirSnap.exists;
      tx.set(myDoc, {
        'at': FieldValue.serverTimestamp(),
        'matched': theyLikeMe,
      });
      if (theyLikeMe) {
        final ids = [me, them]..sort();
        tx.set(_db.collection('matches').doc(ids.join('_')), {
          'users': ids,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Only flip the flag when it is not already true: rules let the
        // named user set matched=true exactly once.
        if (theirSnap.data()?['matched'] != true) {
          tx.update(theirDoc, {'matched': true});
        }
      }
      return theyLikeMe;
    });
    if (matched) {
      await _ensureConversation(me, them);
    }
    return matched;
  }

  Future<void> swipeLeft(String me, String them) async {
    await _db
        .collection('users')
        .doc(me)
        .collection('passes')
        .doc(them)
        .set({'at': FieldValue.serverTimestamp()});
  }

  Future<Set<String>> seenBuddyIds(String me) async {
    final likes =
        await _db.collection('users').doc(me).collection('likesGiven').get();
    final passes =
        await _db.collection('users').doc(me).collection('passes').get();
    return {
      ...likes.docs.map((d) => d.id),
      ...passes.docs.map((d) => d.id),
      me,
    };
  }

  Future<List<BuddyCard>> buddyCandidates(String me, {int limit = 30}) async {
    final seen = await seenBuddyIds(me);
    // Blocked in either direction: never show them in the deck.
    final blocked = await blockedUids(me);
    final blockedMe = await blockedByMe(me);
    final snap = await _db.collection('users').limit(60).get();
    final out = <BuddyCard>[];
    for (final d in snap.docs) {
      if (seen.contains(d.id)) continue;
      if (blocked.contains(d.id) || blockedMe.contains(d.id)) continue;
      final m = d.data();
      out.add(BuddyCard(
        uid: d.id,
        name: m['name'] ?? 'Traveler',
        age: (m['age'] as num?)?.toInt() ?? 0,
        location: m['location'] ?? '',
        photoUrl: m['photoUrl'] ?? '',
        bio: m['bio'] ?? '',
        interests: stringList(m['interests']),
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------- Messaging ----------
  Future<String> _ensureConversation(String a, String b,
      {String kind = 'buddy',
      String lastMessage = 'You matched! Say hi 👋'}) async {
    final ids = [a, b]..sort();
    final convId = ids.join('_');
    final ref = _db.collection('conversations').doc(convId);
    final snap = await ref.get();
    if (!snap.exists) {
      final other = await _db.collection('users').doc(b).get();
      final me = await _db.collection('users').doc(a).get();
      await ref.set({
        'memberIds': ids,
        'kind': kind,
        'isGroup': false,
        'groupName': '',
        'photoUrl': '',
        'names': {a: me.data()?['name'] ?? '', b: other.data()?['name'] ?? ''},
        'photos': {
          a: me.data()?['photoUrl'] ?? '',
          b: other.data()?['photoUrl'] ?? ''
        },
        'lastMessage': lastMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return convId;
  }

  Future<String> conversationWith(String me, String them) =>
      _ensureConversation(me, them);

  /// Opens (or creates) a 1:1 conversation in the given inbox [kind]
  /// ('buddy' | 'marketplace' | 'friend').
  Future<String> startDirectConversation(String me, String them,
          {String kind = 'buddy'}) =>
      _ensureConversation(me, them,
          kind: kind, lastMessage: 'Say hi and start planning! 👋');

  /// Creates a group conversation. Returns the new conversation id.
  Future<String> createGroupConversation({
    required String creatorUid,
    required String groupName,
    required List<String> memberUids,
    String photoUrl = '',
  }) async {
    final members = {creatorUid, ...memberUids}.toList();
    final doc = await _db.collection('conversations').add({
      'memberIds': members,
      'kind': 'buddy',
      'isGroup': true,
      'groupName': groupName,
      'photoUrl': photoUrl,
      'names': {},
      'photos': {},
      'createdBy': creatorUid,
      'lastMessage': '$groupName created',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<Conversation>> conversationStream(String me) => _db
      .collection('conversations')
      .where('memberIds', arrayContains: me)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final m = d.data();
            final ids = stringList(m['memberIds']);
            final isGroup = m['isGroup'] == true;
            final other = ids.firstWhere((i) => i != me, orElse: () => me);
            final names = stringMap(m['names']);
            final photos = stringMap(m['photos']);
            return Conversation(
              id: d.id,
              memberIds: ids,
              otherUid: isGroup ? '' : other,
              otherName: isGroup
                  ? (m['groupName']?.toString() ?? 'Group')
                  : (names[other] ?? 'Traveler'),
              otherPhoto: isGroup
                  ? (m['photoUrl']?.toString() ?? '')
                  : (photos[other] ?? ''),
              lastMessage: m['lastMessage']?.toString() ?? '',
              updatedAt: dateTimeOf(m['updatedAt']),
              isGroup: isGroup,
              groupName: (m['groupName']?.toString() ?? ''),
              photoUrl: (m['photoUrl']?.toString() ?? ''),
              kind: (m['kind']?.toString() ?? 'buddy'),
            );
          }).toList());

  Stream<List<ChatMessage>> messageStream(String convId) => _db
      .collection('conversations')
      .doc(convId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());

  Future<void> sendMessage(String convId, String senderId, String text) async {
    final ref = _db.collection('conversations').doc(convId);
    await ref.collection('messages').add({
      'senderId': senderId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await ref.update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Users ----------
  Future<AppUser?> getUser(String uid) async {
    try {
      final d = await _db.collection('users').doc(uid).get();
      if (!d.exists || d.data() == null) return null;
      return AppUser.fromMap(d.id, d.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Case-insensitive name search over a bounded user sample.
  Future<List<AppUser>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snap = await _db.collection('users').limit(60).get();
      final out = <AppUser>[];
      for (final d in snap.docs) {
        final u = AppUser.fromMap(d.id, d.data());
        if (u.name.toLowerCase().contains(q)) out.add(u);
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  // ---------- Follows ----------
  /// Uids [uid] follows, as a live set.
  Stream<Set<String>> followingIds(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('following')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  /// Uids following [uid].
  Future<Set<String>> followerIds(String uid) async {
    try {
      final s =
          await _db.collection('users').doc(uid).collection('followers').get();
      return s.docs.map((d) => d.id).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> followUser(String me, String them) async {
    if (me.isEmpty || them.isEmpty || me == them) return;
    try {
      final batch = _db.batch();
      batch.set(
          _db.collection('users').doc(me).collection('following').doc(them),
          {'at': FieldValue.serverTimestamp()});
      batch.set(
          _db.collection('users').doc(them).collection('followers').doc(me),
          {'at': FieldValue.serverTimestamp()});
      batch.update(_db.collection('users').doc(me),
          {'following': FieldValue.increment(1)});
      batch.update(_db.collection('users').doc(them),
          {'followers': FieldValue.increment(1)});
      await batch.commit();
    } catch (_) {}
  }

  Future<void> unfollowUser(String me, String them) async {
    if (me.isEmpty || them.isEmpty) return;
    try {
      final batch = _db.batch();
      batch.delete(
          _db.collection('users').doc(me).collection('following').doc(them));
      batch.delete(
          _db.collection('users').doc(them).collection('followers').doc(me));
      batch.update(_db.collection('users').doc(me),
          {'following': FieldValue.increment(-1)});
      batch.update(_db.collection('users').doc(them),
          {'followers': FieldValue.increment(-1)});
      await batch.commit();
    } catch (_) {}
  }

  // ---------- Stories ----------
  /// Non-expired stories, newest first. The expiresAt range filter is
  /// sorted and expiry-checked client-side (docs store ISO-8601 strings,
  /// which a Timestamp comparison cannot filter) so no composite index
  /// is required.
  Stream<List<Story>> storyStream() =>
      _db.collection('stories').snapshots().map((s) {
        final list = s.docs
            .map((d) => Story.fromMap(d.id, d.data()))
            .where((st) => !st.isExpired)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> postStory(Story story) async {
    await _db.collection('stories').add(story.toMap());
  }

  // ---------- Travel invitations ----------
  Stream<List<TravelInvitation>> invitationStream({int limit = 40}) => _db
      .collection('invitations')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => TravelInvitation.fromMap(d.id, d.data())).toList());

  Future<TravelInvitation?> getInvitation(String id) async {
    try {
      final d = await _db.collection('invitations').doc(id).get();
      if (!d.exists || d.data() == null) return null;
      return TravelInvitation.fromMap(d.id, d.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Writes the invitation plus its lightweight geo alert (see
  /// [InvitationAlert] docs and create_post_screen.dart for the
  /// Cloud-Function-free fan-out design).
  Future<String> createInvitation(TravelInvitation inv) async {
    final doc = await _db.collection('invitations').add(inv.toMap());
    try {
      await _db.collection('invitation_alerts').add({
        'invitationId': doc.id,
        'uid': inv.uid,
        'userName': inv.userName,
        'what': inv.what,
        'where': inv.where,
        'geoKey': inv.where.toLowerCase().trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    return doc.id;
  }

  Future<void> toggleInvitationInterest(
      String invitationId, String uid, bool interested) async {
    final ref = _db.collection('invitations').doc(invitationId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final list = stringList(snap.data()?['interestedUids']);
        if (interested) {
          if (!list.contains(uid)) list.add(uid);
        } else {
          list.remove(uid);
        }
        tx.update(ref, {'interestedUids': list});
      });
    } catch (_) {}
  }

  Stream<List<InvitationAlert>> invitationAlertStream({int limit = 50}) => _db
      .collection('invitation_alerts')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => InvitationAlert.fromMap(d.id, d.data())).toList());

  // ---------- Notifications ----------
  Stream<List<AppNotification>> notificationStream(String uid,
          {int limit = 50}) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs
              .map((d) => AppNotification.fromMap(d.id, d.data()))
              .toList());

  Future<void> addNotification(String uid, AppNotification n) async {
    if (uid.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(n.toMap());
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ---------- Follow requests ----------
  /// Uids whose follow requests [uid] declined (followers they do not
  /// follow back and dismissed from the Requests inbox tab).
  Future<Set<String>> declinedRequestIds(String uid) async {
    try {
      final s = await _db
          .collection('users')
          .doc(uid)
          .collection('declinedRequests')
          .get();
      return s.docs.map((d) => d.id).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> declineRequest(String me, String them) async {
    try {
      await _db
          .collection('users')
          .doc(me)
          .collection('declinedRequests')
          .doc(them)
          .set({'at': FieldValue.serverTimestamp()});
    } catch (_) {}
  }
}
