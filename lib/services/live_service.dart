import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monetization_models.dart';

/// Firestore access for live streams and stream chat.
/// Collections: live_streams/{id}, live_streams/{id}/chat/{msgId}
///
/// Streams carry metadata and chat only. Video transport is handled by
/// [LiveVideoProvider]; gift sending is disabled until a compliant payment
/// provider is integrated, and person-to-person money transfers are never
/// allowed in this app.
class LiveService {
  // Lazily resolved so constructing this class never crashes when Firebase
  // has not been configured yet (methods only run while signed in).
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('live_streams');

  /// Adds a stream document and returns its id. The caller is expected to
  /// pass a stream whose status is 'scheduled' or 'live'.
  Future<String> startStream(LiveStream s) async {
    final doc = await _col.add(s.toMap());
    return doc.id;
  }

  Future<void> endStream(String id) async {
    await _col.doc(id).update({'status': 'ended'});
  }

  Stream<List<LiveStream>> liveStreams() => _col
      .where('status', isEqualTo: 'live')
      .orderBy('scheduledAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LiveStream.fromMap(d.id, d.data())).toList());

  Stream<List<LiveStream>> upcomingStreams() => _col
      .where('status', isEqualTo: 'scheduled')
      .orderBy('scheduledAt')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => LiveStream.fromMap(d.id, d.data())).toList());

  /// Increments the viewer count when a viewer joins.
  Future<void> joinStream(String id) async {
    final ref = _col.doc(id);
    await _db.runTransaction((tx) async {
      tx.update(ref, {'viewerCount': FieldValue.increment(1)});
    });
  }

  /// Decrements the viewer count when a viewer leaves. Clamped at zero: a
  /// leave without a matching join (join failed, double dispose) must not
  /// drive the count negative.
  Future<void> leaveStream(String id) async {
    final ref = _col.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['viewerCount'] as num?)?.toInt() ?? 0;
      if (current > 0) {
        tx.update(ref, {'viewerCount': FieldValue.increment(-1)});
      }
    });
  }

  Stream<List<LiveChatMessage>> chatStream(String id) =>
      _col.doc(id).collection('chat').orderBy('sentAt').snapshots().map((s) =>
          s.docs.map((d) => LiveChatMessage.fromMap(d.id, d.data())).toList());

  Future<void> sendChat(String streamId, LiveChatMessage m) async {
    await _col.doc(streamId).collection('chat').add(m.toMap());
  }
}
