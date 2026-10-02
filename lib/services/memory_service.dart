import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Quest memories: photo moments pinned on quest places.
///
/// Collection layout: `memories/{memoryId}`. Every write stores
/// `createdAt` as an ISO-8601 string (matching [Memory.toMap]); reads
/// accept either an ISO string or a Firestore Timestamp via
/// [dateTimeOf], so mixed documents never crash a stream.
class MemoryService {
  static final MemoryService _i = MemoryService._();
  factory MemoryService() => _i;
  MemoryService._();

  // Lazily resolved so constructing this class never crashes when Firebase
  // has not been configured yet.
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  static List<Memory> _decode(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => Memory.fromMap(d.id, d.data())).toList();

  /// All memories pinned on [placeId], newest first.
  ///
  /// When [publicOnly] is true, only 'public' memories stream through;
  /// pass false to include the viewer's own 'only_me' memories (the UI
  /// filters those by owner uid).
  Stream<List<Memory>> forPlace(String placeId, {bool publicOnly = true}) {
    var q = _db
        .collection('memories')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true);
    if (publicOnly) q = q.where('privacy', isEqualTo: 'public');
    return q.snapshots().map(_decode);
  }

  /// The user's own memories (public and only-me), newest first.
  Future<List<Memory>> myMemories(String uid) async {
    final snap = await _db
        .collection('memories')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return _decode(snap);
  }

  /// Live stream of the user's own memories (public and only-me), newest
  /// first. The profile listens to this so a newly posted memory appears
  /// instantly without a manual refresh.
  Stream<List<Memory>> myMemoriesStream(String uid) => _db
      .collection('memories')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(_decode);

  /// Changes a memory's privacy. Only 'public' and 'only_me' are accepted.
  Future<void> setPrivacy(String memoryId, String privacy) async {
    if (privacy != 'public' && privacy != 'only_me') {
      throw Exception('Please choose who can see this memory.');
    }
    await _db.collection('memories').doc(memoryId).update({
      'privacy': privacy,
    });
  }

  /// Deletes a memory and its uploaded photos.
  Future<void> deleteMemory(Memory memory) async {
    for (final url in memory.photoUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Photo may already be gone; the Firestore doc is what matters.
      }
    }
    await _db.collection('memories').doc(memory.id).delete();
  }

  /// The public memories feed: 'public' memories across all places,
  /// newest first.
  Stream<List<Memory>> publicFeed({int limit = 50}) => _db
      .collection('memories')
      .where('privacy', isEqualTo: 'public')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_decode);

  /// Posts a memory: uploads each photo in [localPhotoPaths] to
  /// `memories/<uid>/<timestamp>.jpg`, then writes the Firestore doc.
  ///
  /// Throws a friendly Exception on failure (the caller shows a snackbar).
  Future<void> postMemory({
    required AppUser user,
    required QuestPlace place,
    required String caption,
    required List<String> localPhotoPaths,
    required String privacy,
  }) async {
    if (privacy != 'public' && privacy != 'only_me') {
      throw Exception('Please choose who can see this memory.');
    }
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final urls = <String>[];
      for (var i = 0; i < localPhotoPaths.length; i++) {
        final ref = _storage.ref().child('memories/${user.uid}/$ts-$i.jpg');
        await ref.putFile(File(localPhotoPaths[i]));
        urls.add(await ref.getDownloadURL());
      }
      await _db.collection('memories').add({
        'uid': user.uid,
        'userName': user.name,
        'userPhoto': user.photoUrl,
        'placeId': place.id,
        'placeName': place.name,
        'caption': caption,
        'photoUrls': urls,
        'privacy': privacy,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e is Exception && e.toString().contains('Please choose')) rethrow;
      throw Exception('Could not post your memory. Please try again.');
    }
  }
}
