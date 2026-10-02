import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/boho_theme.dart';

/// Notification inbox: likes, comments, follows, invitation alerts near
/// the user, and match teasers.
///
/// Teaser rule: a 'view' or 'like' notification from matching shows ONLY
/// the actor's photo with "Someone viewed/liked you" unless the viewer is
/// a premium traveler, in which case the full name shows.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final meUid = me?.uid ?? '';
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Notifications',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: meUid.isEmpty
                ? null
                : () => NotificationService().markAllRead(meUid),
            child: Text('Mark all read',
                style: BohoFonts.body(13,
                    color: BohoColors.forest, weight: FontWeight.w700)),
          ),
        ],
      ),
      body: me == null
          ? Center(
              child: Text('Sign in to see your notifications.',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _InvitesNearYou(me: me),
                const SizedBox(height: 8),
                StreamBuilder<List<AppNotification>>(
                  stream: NotificationService().notifications(meUid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: BohoColors.forest),
                        ),
                      );
                    }
                    final notifs = snap.data ?? const <AppNotification>[];
                    if (notifs.isEmpty) {
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(32, 40, 32, 40),
                        child: Column(
                          children: [
                            const HibiscusStamp(
                                size: 56, opacity: 0.5),
                            const SizedBox(height: 14),
                            Text(
                              'All quiet for now.\nPost, like, and follow to stir things up!',
                              style: BohoFonts.body(15,
                                  color: BohoColors.espresso),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Text('Latest',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                        ),
                        ...notifs.map((n) => _NotificationTile(
                            notification: n,
                            isPremium: me.isPremiumActive)),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

/// Travel invitations near the viewer, matched client-side from the
/// lightweight `invitation_alerts` docs (see [InvitationAlert]).
class _InvitesNearYou extends StatelessWidget {
  final AppUser me;
  const _InvitesNearYou({required this.me});

  bool _matches(String geoKey) {
    final mine = me.location.trim().toLowerCase();
    final key = geoKey.trim().toLowerCase();
    if (mine.isEmpty || key.isEmpty) return false;
    return key.contains(mine) || mine.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InvitationAlert>>(
      stream: NotificationService().inviteAlerts(),
      builder: (context, snap) {
        final alerts = (snap.data ?? const <InvitationAlert>[])
            .where((a) => a.uid != me.uid && _matches(a.geoKey))
            .take(5)
            .toList();
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('Invites near you ✈️',
                  style: BohoFonts.heading(17,
                      color: BohoColors.espresso)),
            ),
            ...alerts.map((a) => _InviteAlertTile(alert: a, meUid: me.uid)),
          ],
        );
      },
    );
  }
}

class _InviteAlertTile extends StatelessWidget {
  final InvitationAlert alert;
  final String meUid;
  const _InviteAlertTile({required this.alert, required this.meUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: BohoColors.terracotta.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.airplane_ticket_outlined,
                color: BohoColors.terracotta, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.what.isEmpty ? 'Travel invite' : alert.what,
                    style: BohoFonts.body(15,
                        color: BohoColors.espresso,
                        weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${alert.userName} · ${alert.where}',
                  style: BohoFonts.body(13, color: BohoColors.espresso),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(timeago.format(alert.createdAt),
                    style: BohoFonts.body(11, color: BohoColors.espresso)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _toggleInterest(context),
            child: Text("I'm in",
                style: BohoFonts.body(13,
                    color: BohoColors.forest,
                    weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleInterest(BuildContext context) async {
    final inv =
        await DatabaseService().getInvitation(alert.invitationId);
    if (inv == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('This invite is no longer available.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ));
      }
      return;
    }
    final interested = inv.interestedUids.contains(meUid);
    await DatabaseService()
        .toggleInvitationInterest(inv.id, meUid, !interested);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            interested
                ? 'Removed your interest.'
                : "You're on the list! ✈️",
            style: BohoFonts.body(14, color: Colors.white)),
        backgroundColor: BohoColors.leafDeep,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isPremium;
  const _NotificationTile(
      {required this.notification, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final teaser = n.isMatchTeaser && !isPremium;
    final title = teaser
        ? (n.type == 'view' ? 'Someone viewed you 👀' : 'Someone liked you 💛')
        : (n.title.isEmpty ? _fallbackTitle(n.type) : n.title);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.read ? Colors.white : BohoColors.leafMist,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: n.read
              ? BohoColors.tan.withValues(alpha: 0.6)
              : BohoColors.forest.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
                backgroundImage: n.actorPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(n.actorPhoto)
                    : null,
                child: n.actorPhoto.isEmpty
                    ? Icon(_iconFor(n.type),
                        color: BohoColors.espresso, size: 22)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(n.type),
                      size: 13, color: BohoColors.terracotta),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso,
                        weight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (!teaser && n.body.isNotEmpty)
                  Text(n.body,
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(timeago.format(n.createdAt),
                    style: BohoFonts.body(11,
                        color: BohoColors.espresso)),
              ],
            ),
          ),
          if (!n.read)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: BohoColors.terracotta,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  static String _fallbackTitle(String type) {
    switch (type) {
      case 'like':
        return 'Someone liked your post';
      case 'comment':
        return 'New comment on your post';
      case 'follow':
        return 'You have a new follower';
      case 'match':
        return "It's a match! 🎉";
      case 'invitation':
        return 'New travel invite near you';
      default:
        return 'New notification';
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'view':
        return Icons.visibility_rounded;
      case 'match':
        return Icons.celebration_rounded;
      case 'invitation':
        return Icons.airplane_ticket_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
