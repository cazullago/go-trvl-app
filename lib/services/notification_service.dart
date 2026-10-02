import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'database_service.dart';

/// Notification inbox access for the feed bell badge and
/// [NotificationsScreen].
///
/// Writes happen at the interaction site (feed like/comment buttons, follow
/// buttons) via the notify* helpers below, which skip self-notifications.
/// Reads are plain Firestore streams under users/{uid}/notifications.
///
/// Engagement notifications (like / comment / follow) honor the recipient's
/// `notifyLikes` user-doc preference; match notifications honor
/// `notifyMatches`. Missing doc/field defaults to true (notifications on).
class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  DatabaseService get _db => DatabaseService();

  /// Reads a notification-preference flag from the recipient's user doc.
  Future<bool> _wants(String uid, String key) async {
    try {
      final d =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final v = d.data()?[key];
      if (v is bool) return v;
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Number of unread notifications, for the feed bell badge.
  Stream<int> unreadCount(String uid) =>
      _db.notificationStream(uid).map((ns) => ns.where((n) => !n.read).length);

  Stream<List<AppNotification>> notifications(String uid) =>
      _db.notificationStream(uid);

  /// Recent invitation geo-alerts (see [InvitationAlert]).
  Stream<List<InvitationAlert>> inviteAlerts() =>
      _db.invitationAlertStream();

  Future<void> markAllRead(String uid) =>
      _db.markAllNotificationsRead(uid);

  Future<void> notifyLike({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String fromPhoto,
    required String postId,
  }) async {
    if (toUid.isEmpty || toUid == fromUid) return;
    if (!await _wants(toUid, 'notifyLikes')) return;
    await _db.addNotification(
      toUid,
      AppNotification(
        id: '',
        type: 'like',
        actorUid: fromUid,
        actorName: fromName,
        actorPhoto: fromPhoto,
        title: '$fromName liked your post',
        body: 'Your adventure is getting love.',
        postId: postId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyComment({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String fromPhoto,
    required String postId,
    required String snippet,
  }) async {
    if (toUid.isEmpty || toUid == fromUid) return;
    if (!await _wants(toUid, 'notifyLikes')) return;
    await _db.addNotification(
      toUid,
      AppNotification(
        id: '',
        type: 'comment',
        actorUid: fromUid,
        actorName: fromName,
        actorPhoto: fromPhoto,
        title: '$fromName commented on your post',
        body: snippet.length > 90 ? '${snippet.substring(0, 90)}…' : snippet,
        postId: postId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyFollow({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String fromPhoto,
  }) async {
    if (toUid.isEmpty || toUid == fromUid) return;
    if (!await _wants(toUid, 'notifyLikes')) return;
    await _db.addNotification(
      toUid,
      AppNotification(
        id: '',
        type: 'follow',
        actorUid: fromUid,
        actorName: fromName,
        actorPhoto: fromPhoto,
        title: '$fromName started following you',
        body: 'Say hi and plan something together.',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// "You matched with X" — written to the FIRST liker when the mutual like
  /// completes (they are not looking at the swipe deck at that moment).
  Future<void> notifyMatch({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String fromPhoto,
  }) async {
    if (toUid.isEmpty || toUid == fromUid) return;
    if (!await _wants(toUid, 'notifyMatches')) return;
    try {
      await _db.addNotification(
        toUid,
        AppNotification(
          id: '',
          type: 'match',
          actorUid: fromUid,
          actorName: fromName,
          actorPhoto: fromPhoto,
          title: 'New travel buddy match',
          body: '$fromName liked you back — say hi!',
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }
}
