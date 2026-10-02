import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/live_service.dart';
import '../services/memory_service.dart';
import '../services/game_service.dart';
import '../services/feed_merge.dart';
import '../services/content_filter.dart';
import '../services/moderation_service.dart';
import '../services/notification_service.dart';
import '../services/app_config_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/level_badge.dart';
import 'create_post_screen.dart';
import 'live_viewer_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';

/// FEED tab: "Go Feed".
///
/// Header ("Go" script + "Feed"), notifications bell with an unread badge,
/// messages icon, stories row (GO LIVE tile + live streams + 24h stories),
/// user/post search, and one merged timeline of posts, quest memories,
/// travel invitations and live streams. Pull-to-refresh re-subscribes the
/// timeline streams.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _query = '';
  int _refreshTick = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshTick++);
    // Give the re-subscribed streams a beat to emit.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final meUid = me?.uid ?? '';
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          color: BohoColors.forest,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(meUid)),
              SliverToBoxAdapter(child: _search()),
              SliverToBoxAdapter(child: _StoriesRow(me: me)),
              if (_query.trim().isNotEmpty)
                SliverToBoxAdapter(
                    child: _UserResults(query: _query, meUid: meUid)),
              SliverToBoxAdapter(
                child: _FeedTimeline(
                  key: ValueKey(_refreshTick),
                  query: _query,
                  meUid: meUid,
                  me: me,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String meUid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          Text('Go', style: BohoFonts.script(30, color: BohoColors.terracotta)),
          const SizedBox(width: 6),
          Text('Feed',
              style: BohoFonts.heading(26, color: BohoColors.espresso)),
          const Spacer(),
          // Notifications bell with unread badge.
          StreamBuilder<int>(
            stream: meUid.isEmpty
                ? const Stream<int>.empty()
                : NotificationService().unreadCount(meUid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined,
                        color: BohoColors.espresso, size: 26),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BohoColors.terracotta,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: BohoFonts.body(10,
                              color: Colors.white, weight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.mail_outline_rounded,
                color: BohoColors.espresso, size: 26),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _search() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: SearchBarField(
        hint: 'Search users or posts',
        controller: _searchController,
        onChanged: (q) => setState(() => _query = q),
      ),
    );
  }
}

/// Matching travelers for the search query, with follow buttons.
class _UserResults extends StatelessWidget {
  final String query;
  final String meUid;
  const _UserResults({required this.query, required this.meUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: meUid.isEmpty
          ? Future.value(<String>{})
          : DatabaseService().blockedUids(meUid),
      builder: (context, bsnap) {
        final blocked = bsnap.data ?? const <String>{};
        return FutureBuilder<List<AppUser>>(
          future: DatabaseService().searchUsers(query),
          builder: (context, snap) {
            final users = (snap.data ?? const [])
                .where((u) => u.uid != meUid && !blocked.contains(u.uid))
                .toList();
            if (users.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                  child: SectionHeader(title: 'Travelers'),
                ),
                ...users.map((u) => _UserRow(user: u, meUid: meUid)),
              ],
            );
          },
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final String meUid;
  const _UserRow({required this.user, required this.meUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.all(10),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
            backgroundImage: user.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: BohoFonts.heading(20, color: BohoColors.espresso),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.name,
                          style: BohoFonts.body(15,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    LevelBadge(points: user.points),
                  ],
                ),
                if (user.location.isNotEmpty)
                  Text(user.location,
                      style: BohoFonts.body(12, color: BohoColors.espresso),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FollowButton(targetUid: user.uid, meUid: meUid),
        ],
      ),
    );
  }
}

/// Follow / Following toggle backed by the followingIds stream.
class _FollowButton extends StatelessWidget {
  final String targetUid;
  final String meUid;
  const _FollowButton({required this.targetUid, required this.meUid});

  @override
  Widget build(BuildContext context) {
    if (meUid.isEmpty || meUid == targetUid) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Set<String>>(
      stream: DatabaseService().followingIds(meUid),
      builder: (context, snap) {
        final following = snap.data ?? const <String>{};
        final isFollowing = following.contains(targetUid);
        return OutlinedButton(
          onPressed: () => _toggle(context, isFollowing),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                isFollowing ? Colors.transparent : BohoColors.forest,
            foregroundColor: isFollowing ? BohoColors.forest : Colors.white,
            side: const BorderSide(color: BohoColors.forest, width: 1.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: BohoFonts.body(13, weight: FontWeight.w700),
          ),
          child: Text(isFollowing ? 'Following' : 'Follow'),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, bool isFollowing) async {
    final me = context.read<AuthService>().user;
    if (me == null) return;
    if (isFollowing) {
      await DatabaseService().unfollowUser(meUid, targetUid);
    } else {
      await DatabaseService().followUser(meUid, targetUid);
      await NotificationService().notifyFollow(
        toUid: targetUid,
        fromUid: me.uid,
        fromName: me.name,
        fromPhoto: me.photoUrl,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Stories row
// ---------------------------------------------------------------------------

/// Horizontal stories row: GO LIVE tile (you), live streams, then 24h
/// stories grouped by author (yours first).
class _StoriesRow extends StatefulWidget {
  final AppUser? me;
  const _StoriesRow({required this.me});

  @override
  State<_StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<_StoriesRow> {
  Set<String> _blocked = {};

  @override
  void initState() {
    super.initState();
    final meUid = widget.me?.uid ?? '';
    if (meUid.isNotEmpty) {
      DatabaseService()
          .blockedEitherDirection(meUid)
          .then((s) => mounted ? setState(() => _blocked = s) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meUid = widget.me?.uid ?? '';
    return StreamBuilder<List<Story>>(
      stream: DatabaseService().storyStream(),
      builder: (context, storySnap) {
        // Blocked in either direction: their stories never appear here.
        final stories = (storySnap.data ?? const <Story>[])
            .where((s) => !_blocked.contains(s.uid))
            .toList();
        final byUser = <String, List<Story>>{};
        for (final s in stories) {
          byUser.putIfAbsent(s.uid, () => []).add(s);
        }
        final myStories = byUser.remove(meUid) ?? const <Story>[];
        final others = byUser.values.toList();
        return StreamBuilder<List<LiveStream>>(
          stream: AppConfigService().liveEnabled
              ? LiveService().liveStreams()
              : const Stream<List<LiveStream>>.empty(),
          builder: (context, liveSnap) {
            final live = (liveSnap.data ?? const <LiveStream>[])
                .where((s) => !_blocked.contains(s.creatorUid))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 2),
                  child: SectionHeader(title: 'Stories'),
                ),
                SizedBox(
                  height: 108,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    children: [
                      _goLiveTile(context),
                      _myStoryTile(context, myStories),
                      ...live.map((s) => _liveTile(context, s)),
                      ...others.map((list) => _storyTile(context, list)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _goLiveTile(BuildContext context) {
    return _StoryTileShell(
      label: 'GO LIVE',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => const CreatePostScreen(initialTab: 2)),
      ),
      child: CustomPaint(
        painter: _DashedCirclePainter(color: BohoColors.terracotta),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BohoColors.terracotta.withValues(alpha: 0.15),
          ),
          child: const Center(
            child: Icon(Icons.videocam_rounded,
                color: BohoColors.terracotta, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _myStoryTile(BuildContext context, List<Story> myStories) {
    final has = myStories.isNotEmpty;
    return _StoryTileShell(
      label: has ? 'Your story' : 'Add story',
      onTap: () {
        if (has) {
          _openStoryViewer(context, myStories);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const CreatePostScreen(initialTab: 1)),
          );
        }
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  has ? Border.all(color: BohoColors.forest, width: 3) : null,
            ),
            child: has
                ? _storyAvatar(myStories.first)
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BohoColors.sand.withValues(alpha: 0.7),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_rounded,
                          color: BohoColors.cocoaSoft, size: 26),
                    ),
                  ),
          ),
          if (!has)
            const Positioned(
              right: 2,
              bottom: 2,
              child: Icon(Icons.add_circle_rounded,
                  color: BohoColors.forest, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _liveTile(BuildContext context, LiveStream s) {
    return _StoryTileShell(
      label: s.creatorName.isEmpty ? 'Live' : s.creatorName,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => LiveViewerScreen(streamId: s.id, isCreator: false)),
      ),
      badge: 'LIVE',
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red.shade600, width: 3),
        ),
        child: _avatar(s.creatorPhoto, s.creatorName),
      ),
    );
  }

  Widget _storyTile(BuildContext context, List<Story> list) {
    final first = list.first;
    return _StoryTileShell(
      label: first.userName.isEmpty ? 'Traveler' : first.userName,
      onTap: () => _openStoryViewer(context, list),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: BohoColors.forest, width: 3),
        ),
        child: _storyAvatar(first),
      ),
    );
  }

  Widget _storyAvatar(Story s) {
    return s.photoUrl.isEmpty
        ? _avatar(s.userPhoto, s.userName)
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: s.photoUrl,
              fit: BoxFit.cover,
              width: 62,
              height: 62,
              errorWidget: (_, __, ___) => _avatar(s.userPhoto, s.userName),
            ),
          );
  }

  Widget _avatar(String photoUrl, String name) {
    return CircleAvatar(
      radius: 31,
      backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
      backgroundImage:
          photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: BohoFonts.heading(22, color: BohoColors.espresso),
            )
          : null,
    );
  }

  void _openStoryViewer(BuildContext context, List<Story> stories) {
    showDialog(
      context: context,
      builder: (_) => _StoryViewer(stories: stories),
    );
  }
}

class _StoryTileShell extends StatelessWidget {
  final Widget child;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  const _StoryTileShell(
      {required this.child,
      required this.label,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  if (badge != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(badge!,
                              style: BohoFonts.body(9,
                                  color: Colors.white,
                                  weight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: BohoFonts.body(11,
                    color: BohoColors.espresso, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Dashed circle painter for the GO LIVE tile.
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final r = (size.shortestSide / 2) - 2;
    const dash = 8.0;
    const gap = 6.0;
    double start = 0;
    while (start < 360) {
      final end = (start + (dash / (2 * 3.14159 * r)) * 360).clamp(0, 360);
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.width / 2, size.height / 2), radius: r),
        start * 3.14159 / 180,
        (end - start) * 3.14159 / 180,
        false,
        paint,
      );
      start += ((dash + gap) / (2 * 3.14159 * r)) * 360;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen story viewer: pages through one author's active stories.
class _StoryViewer extends StatefulWidget {
  final List<Story> stories;
  const _StoryViewer({required this.stories});

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    return Dialog(
      backgroundColor: BohoColors.espresso,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: stories.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = stories[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: s.photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: BohoColors.espresso),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 40, 18, 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                          child: Text(
                            s.caption,
                            style: BohoFonts.body(15,
                                color: Colors.white, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Progress dots.
            if (stories.length > 1)
              Positioned(
                top: 54,
                left: 18,
                right: 18,
                child: Row(
                  children: [
                    for (var i = 0; i < stories.length; i++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Author header + close.
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: BohoColors.tan,
                    backgroundImage: stories.first.userPhoto.isNotEmpty
                        ? CachedNetworkImageProvider(stories.first.userPhoto)
                        : null,
                    child: stories.first.userPhoto.isEmpty
                        ? Text(
                            stories.first.userName.isNotEmpty
                                ? stories.first.userName[0].toUpperCase()
                                : '?',
                            style: BohoFonts.heading(16,
                                color: BohoColors.espresso),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stories.first.userName,
                            style: BohoFonts.body(14,
                                color: Colors.white, weight: FontWeight.w700)),
                        Text(timeago.format(stories.first.createdAt),
                            style: BohoFonts.body(11,
                                color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Merged timeline
// ---------------------------------------------------------------------------

/// Subscribes to posts, memories, invitations and live streams once,
/// merges them into one newest-first timeline (live streams pinned on
/// top), and rebuilds on any emission.
class _FeedTimeline extends StatefulWidget {
  final String query;
  final String meUid;
  final AppUser? me;
  const _FeedTimeline(
      {super.key, required this.query, required this.meUid, required this.me});

  @override
  State<_FeedTimeline> createState() => _FeedTimelineState();
}

class _FeedTimelineState extends State<_FeedTimeline> {
  List<Post> _posts = [];
  List<Memory> _memories = [];
  List<TravelInvitation> _invites = [];
  List<LiveStream> _live = [];
  bool _postsReady = false;
  // Uids hidden from this feed in either block direction. Loaded once;
  // an empty set simply disables the filter (fail-open, not fail-empty).
  Set<String> _blocked = {};
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    if (widget.meUid.isNotEmpty) {
      DatabaseService()
          .blockedEitherDirection(widget.meUid)
          .then((s) => mounted ? setState(() => _blocked = s) : null);
    }
    // Hoisted: subscribing in build() would resubscribe on every rebuild.
    // onError keeps a backend hiccup (e.g. a missing composite index)
    // from surfacing as an unhandled async error; the last good list
    // simply stays on screen.
    _subs.addAll([
      DatabaseService().postStream().listen((l) {
        if (mounted)
          setState(() {
            _posts = l;
            _postsReady = true;
          });
      }, onError: (_) {
        // Signed-out reads (or any backend hiccup) must not spin forever:
        // stop loading and show the empty state instead.
        if (mounted) setState(() => _postsReady = true);
      }),
      MemoryService().publicFeed().listen((l) {
        if (mounted) setState(() => _memories = l);
      }, onError: (_) {}),
      DatabaseService().invitationStream().listen((l) {
        if (mounted) setState(() => _invites = l);
      }, onError: (_) {}),
      LiveService().liveStreams().listen((l) {
        if (mounted) setState(() => _live = l);
      }, onError: (_) {}),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<FeedEntry> _merged() {
    return mergeFeedEntries(
      live: _live,
      posts: _posts,
      memories: _memories,
      invitations: _invites,
      blockedUids: _blocked,
      query: widget.query,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_postsReady) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child:
            Center(child: CircularProgressIndicator(color: BohoColors.forest)),
      );
    }
    final entries = _merged();
    if (entries.isEmpty) {
      final q = widget.query.trim();
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 64),
        child: Column(
          children: [
            const HibiscusStamp(size: 64, opacity: 0.5),
            const SizedBox(height: 16),
            Text(
              q.isEmpty
                  ? 'No adventures yet.\nBe the first to post!'
                  : 'No posts match your search.',
              style: BohoFonts.body(16, color: BohoColors.espresso),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return StreamBuilder<Set<String>>(
      stream: widget.meUid.isEmpty
          ? const Stream<Set<String>>.empty()
          : DatabaseService().followingIds(widget.meUid),
      builder: (context, fsnap) {
        final following = fsnap.data ?? const <String>{};
        return Column(
          children: [
            for (final e in entries) _entryCard(e, following),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _entryCard(FeedEntry e, Set<String> following) {
    switch (e.kind) {
      case FeedEntryKind.live:
        return _LiveCard(stream: e.item as LiveStream);
      case FeedEntryKind.post:
        return _PostCard(
          post: e.item as Post,
          meUid: widget.meUid,
          me: widget.me,
          following: following,
        );
      case FeedEntryKind.memory:
        return _MemoryCard(memory: e.item as Memory);
      case FeedEntryKind.invitation:
        return _InvitationCard(
          invitation: e.item as TravelInvitation,
          meUid: widget.meUid,
          following: following,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

BoxDecoration _cardDecor() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
      boxShadow: [
        BoxShadow(
          color: BohoColors.espresso.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );

Widget _avatarOf(String photoUrl, String name, double radius) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
    backgroundImage:
        photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
    child: photoUrl.isEmpty
        ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: BohoFonts.heading(radius, color: BohoColors.espresso),
          )
        : null,
  );
}

/// A live stream rendered as a dark card in the timeline.
class _LiveCard extends StatelessWidget {
  final LiveStream stream;
  const _LiveCard({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BohoColors.espresso, BohoColors.forest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: BohoColors.espresso.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('LIVE',
                    style: BohoFonts.body(11,
                        color: Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.visibility_rounded,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${stream.viewerCount} watching',
                  style: BohoFonts.body(12,
                      color: Colors.white70, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(stream.title,
              style: BohoFonts.heading(18, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('with ${stream.creatorName}',
              style: BohoFonts.body(13,
                  color: Colors.white.withValues(alpha: 0.85),
                  weight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => LiveViewerScreen(
                        streamId: stream.id, isCreator: false)),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text('JOIN LIVE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: BohoFonts.body(15, weight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final String meUid;
  final AppUser? me;
  final Set<String> following;
  const _PostCard(
      {required this.post,
      required this.meUid,
      required this.me,
      required this.following});

  @override
  Widget build(BuildContext context) {
    final liked = post.likedBy.contains(meUid);
    final photos = post.photos;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar, name + level, location · time, follow, menu.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                _avatarOf(post.userPhoto, post.userName, 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(post.userName,
                                style: BohoFonts.body(15,
                                    color: BohoColors.espresso,
                                    weight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          LevelBadge(points: post.authorPoints),
                        ],
                      ),
                      Text(
                        [
                          if (post.locationTag.isNotEmpty) post.locationTag,
                          timeago.format(post.createdAt),
                        ].join(' · '),
                        style: BohoFonts.body(12, color: BohoColors.espresso),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (meUid.isNotEmpty &&
                    meUid != post.uid &&
                    !following.contains(post.uid))
                  TextButton(
                    onPressed: () => _follow(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Follow',
                        style: BohoFonts.body(13,
                            color: BohoColors.forest, weight: FontWeight.w800)),
                  ),
                // Report / Block menu (Apple guideline 1.2).
                if (meUid.isNotEmpty && meUid != post.uid)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: BohoColors.espresso),
                    tooltip: 'More options',
                    onSelected: (v) => _onMenuAction(context, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            const Icon(Icons.flag_outlined,
                                color: BohoColors.terracotta, size: 20),
                            const SizedBox(width: 10),
                            Text('Report',
                                style: BohoFonts.body(15,
                                    color: BohoColors.espresso)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block_rounded,
                                color: BohoColors.terracotta, size: 20),
                            const SizedBox(width: 10),
                            Text('Block traveler',
                                style: BohoFonts.body(15,
                                    color: BohoColors.espresso)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Photos.
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _PhotoPager(photos: photos),
            ),
          // Action row.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liked ? BohoColors.terracotta : BohoColors.espresso,
                  ),
                  onPressed:
                      meUid.isEmpty ? null : () => _toggleLike(context, liked),
                ),
                Text('${post.likes}',
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined,
                      color: BohoColors.espresso),
                  onPressed: () => _openComments(context),
                ),
                Text('${post.commentCount}',
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.share_outlined,
                      color: BohoColors.espresso),
                  tooltip: 'Share',
                  onPressed: () => _share(context),
                ),
              ],
            ),
          ),
          // Caption.
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: RichText(
                text: TextSpan(
                  style: BohoFonts.body(14, color: BohoColors.espresso),
                  children: [
                    TextSpan(
                      text: '${post.userName} ',
                      style: BohoFonts.body(14,
                          color: BohoColors.espresso, weight: FontWeight.w700),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _follow(BuildContext context) async {
    final meUser = me;
    if (meUser == null) return;
    await DatabaseService().followUser(meUid, post.uid);
    await NotificationService().notifyFollow(
      toUid: post.uid,
      fromUid: meUser.uid,
      fromName: meUser.name,
      fromPhoto: meUser.photoUrl,
    );
  }

  Future<void> _toggleLike(BuildContext context, bool liked) async {
    final meUser = me;
    await DatabaseService().toggleLike(post.id, meUid, liked);
    if (!liked && meUser != null && post.uid != meUid) {
      await GameService().awardLikeReceived(post.uid);
      await NotificationService().notifyLike(
        toUid: post.uid,
        fromUid: meUser.uid,
        fromName: meUser.name,
        fromPhoto: meUser.photoUrl,
        postId: post.id,
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final text = [
      if (post.caption.isNotEmpty) post.caption,
      if (post.locationTag.isNotEmpty) '📍 ${post.locationTag}',
      '— via GoTRVL PH',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post copied — share it anywhere 🌊',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.leafDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onMenuAction(BuildContext context, String value) async {
    if (value == 'report') {
      await ModerationService.fileReport(
        context,
        targetType: 'post',
        targetId: post.id,
        authorUid: post.uid,
        reporterUid: meUid,
      );
    } else if (value == 'block') {
      await ModerationService.confirmAndBlock(
        context,
        meUid: meUid,
        otherUid: post.uid,
        otherName: post.userName,
      );
    }
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CommentsSheet(post: post, me: me),
    );
  }
}

/// Swipeable photo area with dots for multi-photo posts.
class _PhotoPager extends StatefulWidget {
  final List<String> photos;
  const _PhotoPager({required this.photos});

  @override
  State<_PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<_PhotoPager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.photos[i],
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: BohoColors.cream,
                  child: const Center(
                    child: CircularProgressIndicator(color: BohoColors.forest),
                  ),
                ),
                errorWidget: (context, _, __) => Container(
                  color: BohoColors.cream,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_rounded,
                        color: BohoColors.tan, size: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? BohoColors.terracotta
                          : BohoColors.tan.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Quest memory card: "🎞️ Memory at <place>".
class _MemoryCard extends StatelessWidget {
  final Memory memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                _avatarOf(memory.userPhoto, memory.userName, 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memory.userName,
                          style: BohoFonts.body(15,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '🎞️ Memory at ${memory.placeName} · ${timeago.format(memory.createdAt)}',
                        style: BohoFonts.body(12,
                            color: BohoColors.forest, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (memory.photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _PhotoPager(photos: memory.photoUrls),
            ),
          if (memory.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(memory.caption,
                  style: BohoFonts.body(14, color: BohoColors.espresso)),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Travel invitation card: WHAT/WHERE/WHO/TIME + "I'm Interested!".
class _InvitationCard extends StatelessWidget {
  final TravelInvitation invitation;
  final String meUid;
  final Set<String> following;
  const _InvitationCard(
      {required this.invitation, required this.meUid, required this.following});

  @override
  Widget build(BuildContext context) {
    final interested = invitation.interestedUids.contains(meUid);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                _avatarOf(invitation.userPhoto, invitation.userName, 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invitation.userName,
                          style: BohoFonts.body(15,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '✈️ Travel invite · ${timeago.format(invitation.createdAt)}',
                        style: BohoFonts.body(12,
                            color: BohoColors.terracotta,
                            weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (meUid.isNotEmpty &&
                    meUid != invitation.uid &&
                    !following.contains(invitation.uid))
                  TextButton(
                    onPressed: () =>
                        DatabaseService().followUser(meUid, invitation.uid),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Follow',
                        style: BohoFonts.body(13,
                            color: BohoColors.forest, weight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BohoColors.sand.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BohoColors.sandDark),
            ),
            child: Column(
              children: [
                _inviteRow('WHAT', invitation.what, Icons.explore_rounded),
                _inviteRow('WHERE', invitation.where, Icons.place_rounded),
                _inviteRow('WHO', invitation.who, Icons.group_rounded),
                _inviteRow('TIME', invitation.time, Icons.schedule_rounded,
                    last: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: meUid.isEmpty
                        ? null
                        : () => DatabaseService().toggleInvitationInterest(
                            invitation.id, meUid, !interested),
                    icon: Icon(
                        interested
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 20),
                    label: Text(interested ? "You're in!" : "I'm Interested!"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: interested
                          ? BohoColors.leafDeep
                          : BohoColors.terracotta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: BohoFonts.body(15, weight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: BohoColors.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BohoColors.tan),
                  ),
                  child: Text(
                    '${invitation.interestedCount} going',
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteRow(String label, String value, IconData icon,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BohoColors.terracotta),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(label,
                style: BohoFonts.capsLabel(11, color: BohoColors.cocoaSoft)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: BohoFonts.body(14,
                  color: BohoColors.espresso, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final AppUser? me;
  const _CommentsSheet({required this.post, required this.me});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  late final Stream<List<PostComment>> _commentStream;

  @override
  void initState() {
    super.initState();
    // Hoisted: a fresh stream in build() would resubscribe on every
    // rebuild (e.g. while typing a comment).
    _commentStream = DatabaseService().commentStream(widget.post.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = widget.me;
    final text = _controller.text.trim();
    if (me == null || text.isEmpty || _sending) return;
    if (!ContentFilter.isAllowed(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ContentFilter.refusalMessage,
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await DatabaseService().addComment(
        widget.post.id,
        PostComment(
          id: const Uuid().v4(),
          uid: me.uid,
          userName: me.name,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      await NotificationService().notifyComment(
        toUid: widget.post.uid,
        fromUid: me.uid,
        fromName: me.name,
        fromPhoto: me.photoUrl,
        postId: widget.post.id,
        snippet: text,
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meUid = widget.me?.uid ?? '';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: BohoColors.tan,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Comments',
                  style: BohoFonts.heading(22, color: BohoColors.espresso)),
            ),
            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: _commentStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: BohoColors.forest),
                    );
                  }
                  final comments = snap.data ?? const [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet. Start the chat!',
                        style: BohoFonts.body(14, color: BohoColors.espresso),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _avatarOf('', c.userName, 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(c.userName,
                                          style: BohoFonts.body(13,
                                              color: BohoColors.espresso,
                                              weight: FontWeight.w700)),
                                      const SizedBox(width: 6),
                                      Text(
                                        timeago.format(c.createdAt),
                                        style: BohoFonts.body(11,
                                            color: BohoColors.espresso),
                                      ),
                                    ],
                                  ),
                                  Text(c.text,
                                      style: BohoFonts.body(14,
                                          color: BohoColors.espresso)),
                                ],
                              ),
                            ),
                            // Report menu (Apple guideline 1.2).
                            if (meUid.isNotEmpty && meUid != c.uid)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    color: BohoColors.espresso, size: 18),
                                tooltip: 'More options',
                                padding: EdgeInsets.zero,
                                onSelected: (v) {
                                  if (v == 'report') {
                                    ModerationService.fileReport(
                                      context,
                                      targetType: 'comment',
                                      targetId: c.id,
                                      authorUid: c.uid,
                                      reporterUid: meUid,
                                      details: 'On post ${widget.post.id}',
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.flag_outlined,
                                            color: BohoColors.terracotta,
                                            size: 20),
                                        const SizedBox(width: 10),
                                        Text('Report',
                                            style: BohoFonts.body(15,
                                                color: BohoColors.espresso)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _sending ? null : _send,
                      backgroundColor: BohoColors.forest,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
