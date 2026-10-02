import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../admin/admin_login_screen.dart';
import '../admin/triple_tap_detector.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/database_service.dart';
import '../services/game_service.dart';
import '../services/memory_service.dart';
import '../services/moderation_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/level_badge.dart';
import '../widgets/ph_stickers.dart';
import '../widgets/premium_upsell_card.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'business_hub_screen.dart';
import 'create_post_screen.dart';

/// Traveler profile. `uid` null (or the current user's) shows the own
/// profile with editing affordances; any other uid shows that traveler's
/// public profile with Follow / Message and report / block.
///
/// Sections: cover + avatar, identity + LevelBadge, stats, level progress,
/// stories, quest memories, passport stamps, premium upsell (own profile).
class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Hidden admin entrance on the profile page itself: 3 taps on the level
  /// badge within 1.5s reveals the admin login. (The Profile tab icon in
  /// the bottom bar has the same gesture.) Obscurity is not security: the
  /// login still requires a real admin credential plus the `admin` custom
  /// claim, verified on a fresh ID token.
  final _adminTapDetector = TripleTapDetector();

  @override
  void initState() {
    super.initState();
    DataService().load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Loads another traveler's profile plus their privacy flags (location
  /// and age visibility). Returns null when the profile cannot be read.
  Future<({AppUser user, bool showLocation, bool showAge})?> _fetchOther(
      String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return (
        user: AppUser.fromMap(uid, data),
        showLocation: data['showLocation'] != false,
        showAge: data['showAge'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final me = auth.user;
        final targetUid = widget.uid ?? me?.uid ?? '';
        if (targetUid.isEmpty) {
          return Scaffold(
            backgroundColor: BohoColors.cream,
            appBar: AppBar(
              backgroundColor: BohoColors.cream,
              title: Text('Profile',
                  style: BohoFonts.heading(22, color: BohoColors.espresso)),
            ),
            body: Center(
              child: Text('Sign in to view your traveler profile.',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
            ),
          );
        }
        final isMine = me != null && targetUid == me.uid;
        if (isMine) {
          return _body(context, auth, me,
              isMine: true, showLocation: true, showAge: true);
        }
        return FutureBuilder<
            ({AppUser user, bool showLocation, bool showAge})?>(
          future: _fetchOther(targetUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: BohoColors.cream,
                body: Center(
                    child: CircularProgressIndicator(color: BohoColors.forest)),
              );
            }
            final data = snap.data;
            if (data == null) {
              return Scaffold(
                backgroundColor: BohoColors.cream,
                appBar: AppBar(backgroundColor: BohoColors.cream),
                body: Center(
                  child: Text('This traveler profile is unavailable.',
                      style: BohoFonts.body(16, color: BohoColors.espresso)),
                ),
              );
            }
            return _body(context, auth, data.user,
                isMine: false,
                showLocation: data.showLocation,
                showAge: data.showAge);
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, AuthService auth, AppUser user,
      {required bool isMine,
      required bool showLocation,
      required bool showAge}) {
    return FutureBuilder<bool>(
      future: GameService().hasAllStamps(user.uid),
      builder: (context, stampSnap) {
        final allStamps = stampSnap.data ?? false;
        final level = GameService().levelFor(user.points, allStamps);
        return Scaffold(
          backgroundColor: BohoColors.cream,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cover(context, auth, user, isMine: isMine),
                _identity(context, auth, user,
                    isMine: isMine,
                    showLocation: showLocation,
                    showAge: showAge,
                    level: level,
                    allStamps: allStamps),
                if (!isMine) _otherActions(context, auth, user),
                _statsRow(user),
                _levelCard(user, level),
                if (isMine) _businessCard(context),
                _storiesRow(user.uid, isMine: isMine),
                _memoriesSection(user, isMine: isMine),
                _stampsSection(user, allStamps: allStamps),
                if (isMine && !user.isPremiumActive) const PremiumUpsellCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Cover + avatar ----------

  Widget _cover(BuildContext context, AuthService auth, AppUser user,
      {required bool isMine}) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: isMine ? () => _changePhoto(user, cover: true) : null,
              child: user.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: BohoColors.tan),
                      errorWidget: (_, __, ___) =>
                          Container(color: BohoColors.tan),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [BohoColors.forest, BohoColors.dustyBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                              left: 24,
                              top: 30,
                              child: PhStickers.coconutTree(size: 72)),
                          Positioned(
                              right: 40,
                              top: 24,
                              child: PhStickers.sun(size: 54)),
                          Positioned(
                              right: 24,
                              bottom: 18,
                              child: PhStickers.wave(size: 64)),
                        ],
                      ),
                    ),
            ),
          ),
          if (isMine && user.coverUrl.isEmpty)
            Positioned(
              right: 16,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Text('Add cover',
                        style: BohoFonts.body(12,
                            color: Colors.white, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (canPop)
                      _roundButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    const Spacer(),
                    if (isMine)
                      _roundButton(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                      )
                    else
                      _roundButton(
                        icon: Icons.more_vert_rounded,
                        tooltip: 'More options',
                        onTap: () => _otherMenu(context, auth, user),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(
      {required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, AuthService auth, AppUser user,
      {required bool isMine,
      required bool showLocation,
      required bool showAge,
      required TravelLevel level,
      required bool allStamps}) {
    final locAge = [
      if (showLocation && user.location.isNotEmpty) user.location,
      if (showAge && user.age > 0) '${user.age}',
    ].join(' \u00B7 ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          Transform.translate(
            offset: const Offset(0, -34),
            child: GestureDetector(
              onTap: isMine ? () => _changePhoto(user, cover: false) : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _avatar(user, 44),
                  ),
                  if (isMine)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: BohoColors.forest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(user.name,
                          style:
                              BohoFonts.heading(24, color: BohoColors.espresso),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_adminTapDetector.registerTap(
                            DateTime.now().millisecondsSinceEpoch)) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const AdminLoginScreen()));
                        }
                      },
                      child: LevelBadge(
                          points: user.points, hasAllStamps: allStamps),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Level ${level.levelNumber} \u00B7 ${level.emoji} ${level.name}',
                    style: BohoFonts.body(13,
                        color: BohoColors.forest, weight: FontWeight.w700)),
                if (locAge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('\u{1F4CD}', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(locAge,
                            style:
                                BohoFonts.body(13, color: BohoColors.cocoaSoft),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(user.bio,
                      style: BohoFonts.body(14, color: BohoColors.espresso),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                ],
                if (isMine) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BohoColors.forest,
                      side: const BorderSide(
                          color: BohoColors.forest, width: 1.2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                    ),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    )),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: Text('Edit profile',
                        style: BohoFonts.body(13, weight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(AppUser user, double radius) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: BohoColors.tan,
      backgroundImage: user.photoUrl.isNotEmpty
          ? CachedNetworkImageProvider(user.photoUrl)
          : null,
      child: user.photoUrl.isEmpty
          ? Text(initial,
              style: BohoFonts.heading(radius, color: BohoColors.forest))
          : null,
    );
  }

  // ---------- Other-user actions ----------

  Widget _otherActions(BuildContext context, AuthService auth, AppUser other) {
    final meUid = auth.user?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: FutureBuilder<bool>(
        future: _isFollowing(meUid, other.uid),
        builder: (context, snap) {
          final following = snap.data ?? false;
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        following ? BohoColors.cream : BohoColors.forest,
                    foregroundColor:
                        following ? BohoColors.forest : Colors.white,
                    side: following
                        ? const BorderSide(color: BohoColors.forest)
                        : BorderSide.none,
                  ),
                  onPressed: () => _toggleFollow(auth, other, following),
                  child: Text(following ? 'Following' : 'Follow'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BohoColors.forest,
                    side:
                        const BorderSide(color: BohoColors.forest, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => _message(auth, other),
                  child: const Text('Message'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _isFollowing(String meUid, String otherUid) async {
    if (meUid.isEmpty) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(meUid)
          .collection('following')
          .doc(otherUid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleFollow(
      AuthService auth, AppUser other, bool following) async {
    final meUid = auth.user?.uid ?? '';
    if (meUid.isEmpty) return;
    try {
      final db = FirebaseFirestore.instance;
      final meRef = db.collection('users').doc(meUid);
      final otherRef = db.collection('users').doc(other.uid);
      await db.runTransaction((tx) async {
        if (following) {
          tx.delete(meRef.collection('following').doc(other.uid));
          tx.delete(otherRef.collection('followers').doc(meUid));
          tx.update(meRef, {'following': FieldValue.increment(-1)});
          tx.update(otherRef, {'followers': FieldValue.increment(-1)});
        } else {
          tx.set(meRef.collection('following').doc(other.uid), {
            'uid': other.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(otherRef.collection('followers').doc(meUid), {
            'uid': meUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(meRef, {'following': FieldValue.increment(1)});
          tx.update(otherRef, {'followers': FieldValue.increment(1)});
        }
      });
      await auth.refreshUser();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  Future<void> _message(AuthService auth, AppUser other) async {
    final meUid = auth.user?.uid ?? '';
    if (meUid.isEmpty) return;
    final convId = await DatabaseService().conversationWith(meUid, other.uid);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: convId,
        otherUid: other.uid,
        otherName: other.name,
        otherPhoto: other.photoUrl,
      ),
    ));
  }

  Future<void> _otherMenu(
      BuildContext context, AuthService auth, AppUser other) async {
    final meUid = auth.user?.uid ?? '';
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            BohoDecor.dragHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.flag_outlined, color: BohoColors.terracotta),
              title: Text('Report profile',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
              onTap: () => Navigator.of(sctx).pop('report'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.block_rounded, color: BohoColors.terracotta),
              title: Text('Block traveler',
                  style: BohoFonts.body(16, color: BohoColors.espresso)),
              onTap: () => Navigator.of(sctx).pop('block'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == 'report' && context.mounted) {
      await ModerationService.fileReport(
        context,
        targetType: 'user',
        targetId: other.uid,
        authorUid: other.uid,
        reporterUid: meUid,
        details: 'Profile of ${other.name}',
      );
    } else if (choice == 'block' && context.mounted) {
      final blocked = await ModerationService.confirmAndBlock(
        context,
        meUid: meUid,
        otherUid: other.uid,
        otherName: other.name,
      );
      if (blocked && context.mounted) Navigator.of(context).pop();
    }
  }

  // ---------- Stats + level ----------

  Widget _statsRow(AppUser user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StreamBuilder<List<Post>>(
            stream: DatabaseService().userPosts(user.uid),
            builder: (context, snap) =>
                _stat('${(snap.data ?? []).length}', 'Posts'),
          ),
          _stat('${user.followers}', 'Followers'),
          _stat('${user.following}', 'Following'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: BohoFonts.heading(20, color: BohoColors.espresso)),
        Text(label,
            style: BohoFonts.body(13,
                color: BohoColors.espresso.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _levelCard(AppUser user, TravelLevel level) {
    // Alamat is the special max level: always full, no "next level".
    final isAlamat = level == TravelLevel.alamat;
    final next = isAlamat ? null : TravelLevel.nextThreshold(user.points);
    final progress =
        TravelLevel.progressInLevel(user.points, hasAllStamps: isAlamat);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Row(
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level ${level.levelNumber} \u00B7 ${level.name}',
                    style: BohoFonts.heading(17, color: BohoColors.espresso)),
                const SizedBox(height: 2),
                Text('${user.points} pts',
                    style: BohoFonts.body(13,
                        color: BohoColors.forest, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
                    color: BohoColors.forest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                    next == null
                        ? 'Max level reached!'
                        : '${next - user.points} pts to next level',
                    style: BohoFonts.body(12,
                        color: BohoColors.espresso.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Entry to the business side of the same account: list services,
  /// manage bookings, and upgrade to premium business tools.
  Widget _businessCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BusinessHubScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: BohoColors.sun.withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: BohoColors.espresso.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BohoColors.sun.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: BohoColors.espresso, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Business profile',
                        style:
                            BohoFonts.heading(15, color: BohoColors.espresso)),
                    const SizedBox(height: 2),
                    Text('List services & grow on GoTRVL',
                        style: BohoFonts.body(12,
                            color: BohoColors.espresso.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: BohoColors.espresso),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Stories ----------

  /// Active stories row (Facebook-style). Stories live in the top-level
  /// `stories` collection and expire after 24h ([Story.isExpired]).
  /// Renders nothing when there are no active stories; never errors.
  Widget _storiesRow(String uid, {required bool isMine}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final stories = (snap.data?.docs ?? [])
            .map((d) {
              try {
                return Story.fromMap(d.id, d.data() as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<Story>()
            .where((s) => !s.isExpired)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (stories.isEmpty && !isMine) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Stories',
                  style: BohoFonts.heading(17, color: BohoColors.espresso)),
            ),
            SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: stories.length + (isMine ? 1 : 0),
                itemBuilder: (context, i) {
                  if (isMine && i == 0) return _addStoryTile(context);
                  final story = stories[isMine ? i - 1 : i];
                  return GestureDetector(
                    onTap: () => _showStory(story),
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [BohoColors.terracotta, BohoColors.sun],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: BohoColors.tan,
                              backgroundImage: story.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(story.photoUrl)
                                  : null,
                              child: story.photoUrl.isEmpty
                                  ? const Icon(Icons.auto_stories_rounded,
                                      color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              story.caption.isNotEmpty
                                  ? story.caption
                                  : 'Story',
                              style: BohoFonts.body(11,
                                  color: BohoColors.espresso),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  /// "+" tile opening the story composer (own profile only).
  Widget _addStoryTile(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => const CreatePostScreen(initialTab: 1)),
      ),
      child: Container(
        width: 70,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: BohoColors.forest.withValues(alpha: 0.5),
                    width: 1.6),
                color: BohoColors.tan.withValues(alpha: 0.4),
              ),
              child: const Icon(Icons.add_rounded,
                  color: BohoColors.forest, size: 28),
            ),
            const SizedBox(height: 4),
            Text('Add story',
                style: BohoFonts.body(11, color: BohoColors.espresso),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showStory(Story story) {
    showDialog(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (story.photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: story.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 240, color: BohoColors.tan),
                  errorWidget: (_, __, ___) =>
                      Container(height: 240, color: BohoColors.tan),
                ),
              ),
            if (story.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(story.caption,
                    style: BohoFonts.body(14, color: Colors.white)),
              ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child:
                  Text('Close', style: BohoFonts.body(14, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Quest memories ----------

  Widget _memoriesSection(AppUser user, {required bool isMine}) {
    return StreamBuilder<List<Memory>>(
      stream: MemoryService().myMemoriesStream(user.uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Text(
                'Could not load memories. Check your connection and pull to refresh.',
                style: BohoFonts.body(13,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: BohoColors.forest)),
          );
        }
        var memories = snap.data ?? [];
        if (!isMine) {
          memories = memories.where((m) => m.privacy == 'public').toList();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Text(
                  '\u{1F39E}\uFE0F ${isMine ? 'MY MEMORIES' : 'MEMORIES'}',
                  style: BohoFonts.heading(17, color: BohoColors.espresso)),
            ),
            if (memories.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                    isMine
                        ? 'Finish a quest and post a memory. It will be pinned here and on the map.'
                        : 'No public memories yet.',
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso.withValues(alpha: 0.6))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: memories.length,
                itemBuilder: (context, i) =>
                    _memoryTile(memories[i], isMine: isMine),
              ),
          ],
        );
      },
    );
  }

  Widget _memoryTile(Memory memory, {required bool isMine}) {
    final photo = memory.photoUrls.isNotEmpty ? memory.photoUrls.first : '';
    return GestureDetector(
      onTap: () => _showMemory(memory, isMine: isMine),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: BohoColors.tan),
                    errorWidget: (_, __, ___) =>
                        Container(color: BohoColors.tan),
                  )
                : Container(color: BohoColors.tan),
            if (memory.privacy != 'public')
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMemory(Memory memory, {required bool isMine}) {
    showDialog(
      context: context,
      builder: (dctx) => _MemoryDialog(memory: memory, isMine: isMine),
    );
  }

  // ---------- Passport stamps ----------

  Widget _stampsSection(AppUser user, {required bool allStamps}) {
    final stamps = user.stamps;
    final total = GameService.totalStamps;
    final locked = (total - stamps.length).clamp(0, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('\u{1F6C2} PASSPORT STAMPS',
                    style: BohoFonts.heading(17, color: BohoColors.espresso)),
              ),
              Text('${stamps.length}/$total',
                  style: BohoFonts.body(13,
                      color: BohoColors.forest, weight: FontWeight.w800)),
            ],
          ),
        ),
        if (allStamps) _alamatBanner(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: stamps.length + locked,
          itemBuilder: (context, i) {
            if (i < stamps.length) {
              return _stampBadge(stamps[i], i);
            }
            return _lockedSlot();
          },
        ),
      ],
    );
  }

  String _stampPlaceName(String stamp) {
    final id = stamp.startsWith('stamp:') ? stamp.substring(6) : stamp;
    try {
      return DataService().placeById(id)?.name ?? id;
    } catch (_) {
      return id;
    }
  }

  Widget _stampBadge(String stamp, int index) {
    final deco = [
      () => PhStickers.coconutTree(size: 30),
      () => PhStickers.sun(size: 28),
      () => PhStickers.wave(size: 30),
      () => PhStickers.shell(size: 28),
    ][index % 4]();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [BohoColors.sun, BohoColors.terracotta],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: BohoColors.cocoaSoft, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: BohoColors.cocoa.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: deco),
        ),
        const SizedBox(height: 4),
        Text(_stampPlaceName(stamp),
            style: BohoFonts.body(9.5, color: BohoColors.espresso),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _lockedSlot() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BohoColors.tan.withValues(alpha: 0.35),
            border: Border.all(
                color: BohoColors.tan.withValues(alpha: 0.6), width: 1.2),
          ),
          child: const Center(
            child: Icon(Icons.lock_outline_rounded,
                color: BohoColors.sandMuted, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text('Locked',
            style: BohoFonts.body(9.5, color: BohoColors.sandMuted),
            textAlign: TextAlign.center),
      ],
    );
  }

  /// Special golden state when every passport stamp is collected.
  Widget _alamatBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD97A), Color(0xFFFFB84D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.cocoaSoft, width: 1.2),
      ),
      child: Row(
        children: [
          PhStickers.parol(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alamat!',
                    style: BohoFonts.script(24, color: BohoColors.espresso)),
                const SizedBox(height: 2),
                Text(
                    'Every passport stamp collected. A true legend of the islands.',
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Photo changes ----------

  /// Changes the avatar or cover: asks for photo permission with the
  /// approved reason string, uploads to Firebase Storage, updates the
  /// user doc, and refreshes auth state.
  Future<void> _changePhoto(AppUser user, {required bool cover}) async {
    final granted = await PermissionService()
        .ensurePhotos(context, 'to update your profile photo');
    if (!granted || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Uploading photo...',
              style: BohoFonts.body(14, color: Colors.white))),
    );
    try {
      final url = await DatabaseService().uploadImage(
        File(picked.path),
        'users/${user.uid}/${cover ? 'cover' : 'avatar'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({cover ? 'coverUrl' : 'photoUrl': url});
      await context.read<AuthService>().refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Photo updated',
                style: BohoFonts.body(14, color: Colors.white)),
            backgroundColor: BohoColors.forest),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not upload the photo. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }
}

/// Memory detail dialog with owner actions.
///
/// A dedicated [StatefulWidget] (rather than [StatefulBuilder]) so the
/// privacy/busy state survives rebuilds and double-taps cannot fire
/// duplicate writes.
class _MemoryDialog extends StatefulWidget {
  final Memory memory;
  final bool isMine;
  const _MemoryDialog({required this.memory, required this.isMine});

  @override
  State<_MemoryDialog> createState() => _MemoryDialogState();
}

class _MemoryDialogState extends State<_MemoryDialog> {
  late Memory _memory;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _memory = widget.memory;
  }

  Memory _withPrivacy(String privacy) => Memory(
        id: _memory.id,
        uid: _memory.uid,
        userName: _memory.userName,
        userPhoto: _memory.userPhoto,
        placeId: _memory.placeId,
        placeName: _memory.placeName,
        caption: _memory.caption,
        photoUrls: _memory.photoUrls,
        privacy: privacy,
        createdAt: _memory.createdAt,
      );

  Future<void> _changePrivacy(String next) async {
    if (next == _memory.privacy || _busy) return;
    setState(() => _busy = true);
    try {
      await MemoryService().setPrivacy(_memory.id, next);
      if (!mounted) return;
      setState(() {
        _memory = _withPrivacy(next);
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update privacy. Please try again.')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (cctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        title: Text('Delete memory?',
            style: BohoFonts.heading(18, color: BohoColors.espresso)),
        content: Text('This memory and its photos will be permanently removed.',
            style: BohoFonts.body(14, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(cctx).pop(false),
            child: Text('Keep',
                style: BohoFonts.body(14, color: BohoColors.forest)),
          ),
          TextButton(
            onPressed: () => Navigator.of(cctx).pop(true),
            child: Text('Delete',
                style: BohoFonts.body(14,
                    color: BohoColors.terracotta, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || _busy) return;
    setState(() => _busy = true);
    try {
      await MemoryService().deleteMemory(_memory);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _memory.photoUrls.isNotEmpty ? _memory.photoUrls.first : '';
    return Dialog(
      backgroundColor: BohoColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(height: 220, color: BohoColors.tan),
                errorWidget: (_, __, ___) =>
                    Container(height: 220, color: BohoColors.tan),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_memory.placeName.isNotEmpty)
                  Text(_memory.placeName,
                      style: BohoFonts.heading(17, color: BohoColors.espresso)),
                if (_memory.caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_memory.caption,
                      style: BohoFonts.body(14, color: BohoColors.espresso)),
                ],
                if (widget.isMine) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PrivacyChoice(
                          label: '\U0001F30D Public',
                          selected: _memory.privacy == 'public',
                          busy: _busy,
                          onTap: () => _changePrivacy('public'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PrivacyChoice(
                          label: '\U0001F512 Only me',
                          selected: _memory.privacy == 'only_me',
                          busy: _busy,
                          onTap: () => _changePrivacy('only_me'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: BohoColors.terracotta),
                    label: Text('Delete memory',
                        style:
                            BohoFonts.body(14, color: BohoColors.terracotta)),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close',
                style: BohoFonts.body(14, color: BohoColors.forest)),
          ),
        ],
      ),
    );
  }
}

class _PrivacyChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  const _PrivacyChoice(
      {required this.label,
      required this.selected,
      required this.busy,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? BohoColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? BohoColors.forest
                : BohoColors.espresso.withValues(alpha: 0.25),
          ),
        ),
        child: Center(
          child: Text(label,
              style: BohoFonts.body(13,
                  color: selected ? Colors.white : BohoColors.espresso,
                  weight: FontWeight.w700)),
        ),
      ),
    );
  }
}
