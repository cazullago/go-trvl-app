import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/moderation_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import 'chat_screen.dart';

/// Message inbox with four tabs: Travel buddies, Marketplace, Friends
/// (mutual follows) and Requests (followers you don't follow back).
/// Blocked users never appear (Apple guideline 1.2).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: BohoColors.cream,
        appBar: AppBar(
          backgroundColor: BohoColors.cream,
          title: Text('Messages',
              style: BohoFonts.heading(22, color: BohoColors.espresso)),
          centerTitle: true,
          actions: [
            if (me != null)
              IconButton(
                tooltip: 'New message',
                icon: const Icon(Icons.add_rounded,
                    color: BohoColors.espresso, size: 26),
                onPressed: () => _showNewMessageSheet(context, me.uid),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: BohoColors.forest,
            unselectedLabelColor: BohoColors.espresso,
            indicatorColor: BohoColors.terracotta,
            labelStyle:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(text: 'Travel buddies'),
              Tab(text: 'Marketplace'),
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: me == null
            ? Center(
                child: Text('Sign in to see your chats.',
                    style: BohoFonts.body(16,
                        color: BohoColors.espresso)),
              )
            : FutureBuilder<Set<String>>(
                future: DatabaseService().blockedUids(me.uid),
                builder: (context, bsnap) {
                  final blocked = bsnap.data ?? const <String>{};
                  return StreamBuilder<List<Conversation>>(
                    stream:
                        DatabaseService().conversationStream(me.uid),
                    builder: (context, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: BohoColors.forest),
                        );
                      }
                      final convos =
                          ModerationService.filterBlockedConversations(
                              snap.data ?? const [], blocked);
                      return TabBarView(
                        children: [
                          _BuddyTab(
                              meUid: me.uid,
                              convos: convos,
                              blocked: blocked),
                          _MarketplaceTab(
                              meUid: me.uid, convos: convos),
                          _FriendsTab(meUid: me.uid, blocked: blocked),
                          _RequestsTab(meUid: me.uid, blocked: blocked),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showNewMessageSheet(BuildContext context, String meUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: BohoColors.forest),
              title: Text('New message',
                  style: BohoFonts.body(16,
                      color: BohoColors.espresso,
                      weight: FontWeight.w700)),
              subtitle: Text('Chat with a traveler',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso)),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUserSearch(context, meUid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined,
                  color: BohoColors.terracotta),
              title: Text('New group',
                  style: BohoFonts.body(16,
                      color: BohoColors.espresso,
                      weight: FontWeight.w700)),
              subtitle: Text('Plan together with a crew',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso)),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          _GroupComposerScreen(meUid: meUid)),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openUserSearch(BuildContext context, String meUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _UserSearchSheet(meUid: meUid),
    );
  }
}

void _openChat(BuildContext context, Conversation c) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: c.id,
        otherUid: c.otherUid,
        otherName: c.otherName,
        otherPhoto: c.otherPhoto,
        isGroup: c.isGroup,
      ),
    ),
  );
}

Widget _emptyState(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HibiscusStamp(size: 52, opacity: 0.5),
          const SizedBox(height: 14),
          Text(text,
              style: BohoFonts.body(15, color: BohoColors.espresso),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ tabs

/// Travel buddies: 1:1 buddy conversations + the "Group pages" entry.
class _BuddyTab extends StatelessWidget {
  final String meUid;
  final List<Conversation> convos;
  final Set<String> blocked;
  const _BuddyTab(
      {required this.meUid, required this.convos, required this.blocked});

  @override
  Widget build(BuildContext context) {
    final buddies =
        convos.where((c) => c.kind == 'buddy' && !c.isGroup).toList();
    final groups = convos.where((c) => c.isGroup).toList();
    if (buddies.isEmpty && groups.isEmpty) {
      return _emptyState(
          'No chats yet — match with a travel buddy first! 💌');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (groups.isNotEmpty)
          _GroupPagesEntry(groups: groups),
        ...buddies.map((c) => _ConversationRow(convo: c)),
      ],
    );
  }
}

/// Entry point to the group pages list.
class _GroupPagesEntry extends StatelessWidget {
  final List<Conversation> groups;
  const _GroupPagesEntry({required this.groups});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => _GroupListScreen(groups: groups)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [BohoColors.terracotta, BohoColors.coral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_rounded,
                color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Group pages',
                      style: BohoFonts.body(16,
                          color: Colors.white,
                          weight: FontWeight.w800)),
                  Text('${groups.length} group${groups.length == 1 ? '' : 's'}',
                      style: BohoFonts.body(13,
                          color:
                              Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceTab extends StatelessWidget {
  final String meUid;
  final List<Conversation> convos;
  const _MarketplaceTab({required this.meUid, required this.convos});

  @override
  Widget build(BuildContext context) {
    final items =
        convos.where((c) => c.kind == 'marketplace').toList();
    if (items.isEmpty) {
      return _emptyState(
          'No marketplace chats yet.\nMessage a local business from its listing to start one.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => _ConversationRow(convo: items[i]),
    );
  }
}

/// Friends: mutual follows, each openable as a friend conversation.
class _FriendsTab extends StatelessWidget {
  final String meUid;
  final Set<String> blocked;
  const _FriendsTab({required this.meUid, required this.blocked});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: DatabaseService().followingIds(meUid),
      builder: (context, fsnap) {
        final following = fsnap.data ?? const <String>{};
        return FutureBuilder<Set<String>>(
          future: DatabaseService().followerIds(meUid),
          builder: (context, flsnap) {
            final followers = flsnap.data ?? const <String>{};
            final mutual = following
                .intersection(followers)
                .where((u) => !blocked.contains(u))
                .toList();
            if (mutual.isEmpty) {
              return _emptyState(
                  'Friends are mutual follows.\nFollow travelers from the feed and they\'ll show up here when they follow back.');
            }
            return FutureBuilder<List<AppUser?>>(
              future: Future.wait(
                  mutual.map((u) => DatabaseService().getUser(u))),
              builder: (context, usnap) {
                final users = (usnap.data ?? const [])
                    .whereType<AppUser>()
                    .toList();
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return _FriendRow(user: u, meUid: meUid);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  final AppUser user;
  final String meUid;
  const _FriendRow({required this.user, required this.meUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: BohoColors.oceanMist,
            backgroundImage: user.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: BohoFonts.heading(20,
                        color: BohoColors.forest),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: BohoFonts.body(16,
                        weight: FontWeight.w700)),
                Text('Mutual follow',
                    style: BohoFonts.body(12,
                        color: BohoColors.forest,
                        weight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: BohoColors.forest),
            onPressed: () async {
              final id = await DatabaseService()
                  .startDirectConversation(meUid, user.uid,
                      kind: 'friend');
              if (context.mounted) {
                _openChat(
                    context,
                    Conversation(
                      id: id,
                      memberIds: [meUid, user.uid],
                      otherUid: user.uid,
                      otherName: user.name,
                      otherPhoto: user.photoUrl,
                      lastMessage: '',
                      updatedAt: DateTime.now(),
                      kind: 'friend',
                    ));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Requests: followers you don't follow back, with Accept / Decline.
class _RequestsTab extends StatelessWidget {
  final String meUid;
  final Set<String> blocked;
  const _RequestsTab({required this.meUid, required this.blocked});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: DatabaseService().followingIds(meUid),
      builder: (context, fsnap) {
        final following = fsnap.data ?? const <String>{};
        return FutureBuilder<List<Set<String>>>(
          future: Future.wait([
            DatabaseService().followerIds(meUid),
            DatabaseService().declinedRequestIds(meUid),
          ]),
          builder: (context, snap) {
            final followers =
                snap.data?.elementAtOrNull(0) ?? const <String>{};
            final declined =
                snap.data?.elementAtOrNull(1) ?? const <String>{};
            final pending = followers
                .where((u) =>
                    u != meUid &&
                    !following.contains(u) &&
                    !declined.contains(u) &&
                    !blocked.contains(u))
                .toList();
            if (pending.isEmpty) {
              return _emptyState('No message requests right now.');
            }
            return FutureBuilder<List<AppUser?>>(
              future: Future.wait(
                  pending.map((u) => DatabaseService().getUser(u))),
              builder: (context, usnap) {
                final users = (usnap.data ?? const [])
                    .whereType<AppUser>()
                    .toList();
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: users.length,
                  itemBuilder: (context, i) =>
                      _RequestRow(user: users[i], meUid: meUid),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RequestRow extends StatefulWidget {
  final AppUser user;
  final String meUid;
  const _RequestRow({required this.user, required this.meUid});

  @override
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: BohoColors.sand,
            backgroundImage: u.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(u.photoUrl)
                : null,
            child: u.photoUrl.isEmpty
                ? Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: BohoFonts.heading(20,
                        color: BohoColors.espresso),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name,
                    style: BohoFonts.body(16,
                        weight: FontWeight.w700)),
                Text('Wants to message you',
                    style: BohoFonts.body(12,
                        color: BohoColors.espresso)),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _decline(),
            child: Text('Decline',
                style: BohoFonts.body(13,
                    color: BohoColors.espresso,
                    weight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _busy ? null : () => _accept(),
            style: ElevatedButton.styleFrom(
              backgroundColor: BohoColors.forest,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Accept',
                style: BohoFonts.body(13,
                    color: Colors.white,
                    weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await DatabaseService().followUser(widget.meUid, widget.user.uid);
      final id = await DatabaseService().startDirectConversation(
          widget.meUid, widget.user.uid,
          kind: 'friend');
      if (mounted) {
        _openChat(
            context,
            Conversation(
              id: id,
              memberIds: [widget.meUid, widget.user.uid],
              otherUid: widget.user.uid,
              otherName: widget.user.name,
              otherPhoto: widget.user.photoUrl,
              lastMessage: '',
              updatedAt: DateTime.now(),
              kind: 'friend',
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await DatabaseService()
          .declineRequest(widget.meUid, widget.user.uid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ------------------------------------------------------------------ rows

class _ConversationRow extends StatelessWidget {
  final Conversation convo;
  const _ConversationRow({required this.convo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openChat(context, convo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BohoDecor.card(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: BohoColors.oceanMist,
              backgroundImage: convo.otherPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(convo.otherPhoto)
                  : null,
              child: convo.otherPhoto.isEmpty
                  ? Text(
                      convo.otherName.isNotEmpty
                          ? convo.otherName[0].toUpperCase()
                          : '?',
                      style: BohoFonts.heading(22,
                          color: BohoColors.forest),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(convo.otherName,
                            style: BohoFonts.body(16,
                                weight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (convo.isGroup) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.group_rounded,
                            size: 16, color: BohoColors.terracotta),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    convo.lastMessage,
                    style: BohoFonts.body(13,
                        color: BohoColors.cocoaSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeago.format(convo.updatedAt),
              style: BohoFonts.body(11, color: BohoColors.cocoaSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ new message

class _UserSearchSheet extends StatefulWidget {
  final String meUid;
  const _UserSearchSheet({required this.meUid});

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text('New message',
                  style:
                      BohoFonts.heading(22, color: BohoColors.espresso)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SearchBarField(
                hint: 'Search travelers by name',
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? Center(
                      child: Text('Type a name to find travelers.',
                          style: BohoFonts.body(14,
                              color: BohoColors.espresso)),
                    )
                  : FutureBuilder<List<AppUser>>(
                      future:
                          DatabaseService().searchUsers(_query),
                      builder: (context, snap) {
                        final users = (snap.data ?? const [])
                            .where((u) => u.uid != widget.meUid)
                            .toList();
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: BohoColors.forest),
                          );
                        }
                        if (users.isEmpty) {
                          return Center(
                            child: Text('No travelers found.',
                                style: BohoFonts.body(14,
                                    color: BohoColors.espresso)),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              20, 4, 20, 24),
                          itemCount: users.length,
                          itemBuilder: (context, i) {
                            final u = users[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: BohoColors.tan
                                    .withValues(alpha: 0.5),
                                backgroundImage:
                                    u.photoUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            u.photoUrl)
                                        : null,
                                child: u.photoUrl.isEmpty
                                    ? Text(
                                        u.name.isNotEmpty
                                            ? u.name[0].toUpperCase()
                                            : '?',
                                        style: BohoFonts.heading(18,
                                            color:
                                                BohoColors.espresso),
                                      )
                                    : null,
                              ),
                              title: Text(u.name,
                                  style: BohoFonts.body(15,
                                      color: BohoColors.espresso,
                                      weight: FontWeight.w700)),
                              subtitle: u.location.isNotEmpty
                                  ? Text(u.location,
                                      style: BohoFonts.body(12,
                                          color:
                                              BohoColors.espresso))
                                  : null,
                              onTap: () => _startChat(u),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChat(AppUser u) async {
    final id = await DatabaseService()
        .startDirectConversation(widget.meUid, u.uid, kind: 'buddy');
    if (!mounted) return;
    Navigator.of(context).pop(); // close the sheet
    _openChat(
        context,
        Conversation(
          id: id,
          memberIds: [widget.meUid, u.uid],
          otherUid: u.uid,
          otherName: u.name,
          otherPhoto: u.photoUrl,
          lastMessage: '',
          updatedAt: DateTime.now(),
        ));
  }
}

// ---------------------------------------------------------- group composer

class _GroupComposerScreen extends StatefulWidget {
  final String meUid;
  const _GroupComposerScreen({required this.meUid});

  @override
  State<_GroupComposerScreen> createState() => _GroupComposerScreenState();
}

class _GroupComposerScreenState extends State<_GroupComposerScreen> {
  final _nameC = TextEditingController();
  String _query = '';
  final _selected = <String, AppUser>{};
  bool _busy = false;

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('New group',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_nameC.text.trim().isEmpty ||
                    _selected.isEmpty ||
                    _busy)
                ? null
                : _create,
            child: Text('Create',
                style: BohoFonts.body(15,
                    color: BohoColors.forest,
                    weight: FontWeight.w800)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _nameC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'e.g. Siargao Crew',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final u in _selected.values)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(u.name,
                            style: BohoFonts.body(13,
                                weight: FontWeight.w600)),
                        deleteIcon:
                            const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () =>
                            setState(() => _selected.remove(u.uid)),
                        backgroundColor:
                            BohoColors.leafMist,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SearchBarField(
              hint: 'Add travelers by name',
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? Center(
                    child: Text('Search to add members.',
                        style: BohoFonts.body(14,
                            color: BohoColors.espresso)),
                  )
                : FutureBuilder<List<AppUser>>(
                    future:
                        DatabaseService().searchUsers(_query),
                    builder: (context, snap) {
                      final users = (snap.data ?? const [])
                          .where((u) => u.uid != widget.meUid)
                          .toList();
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            20, 4, 20, 24),
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          final u = users[i];
                          final picked =
                              _selected.containsKey(u.uid);
                          return CheckboxListTile(
                            value: picked,
                            onChanged: (_) => setState(() {
                              if (picked) {
                                _selected.remove(u.uid);
                              } else {
                                _selected[u.uid] = u;
                              }
                            }),
                            activeColor: BohoColors.forest,
                            title: Text(u.name,
                                style: BohoFonts.body(15,
                                    color: BohoColors.espresso,
                                    weight: FontWeight.w700)),
                            secondary: CircleAvatar(
                              backgroundColor: BohoColors.tan
                                  .withValues(alpha: 0.5),
                              backgroundImage:
                                  u.photoUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          u.photoUrl)
                                      : null,
                              child: u.photoUrl.isEmpty
                                  ? Text(
                                      u.name.isNotEmpty
                                          ? u.name[0]
                                              .toUpperCase()
                                          : '?',
                                      style: BohoFonts.heading(
                                          16,
                                          color:
                                              BohoColors.espresso),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final id = await DatabaseService().createGroupConversation(
        creatorUid: widget.meUid,
        groupName: _nameC.text.trim(),
        memberUids: _selected.keys.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherUid: '',
            otherName: _nameC.text.trim(),
            otherPhoto: '',
            isGroup: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ------------------------------------------------------------ group pages

class _GroupListScreen extends StatelessWidget {
  final List<Conversation> groups;
  const _GroupListScreen({required this.groups});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Group pages',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => _GroupDetailScreen(convo: g)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BohoDecor.card(),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: BohoColors.terracotta
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: BohoColors.terracotta, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(g.groupName.isEmpty ? 'Group' : g.groupName,
                            style: BohoFonts.body(16,
                                color: BohoColors.espresso,
                                weight: FontWeight.w700)),
                        Text(
                            '${g.memberIds.length} members',
                            style: BohoFonts.body(13,
                                color: BohoColors.espresso)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: BohoColors.espresso),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Simple group detail page: members list + shared-photos placeholder.
class _GroupDetailScreen extends StatelessWidget {
  final Conversation convo;
  const _GroupDetailScreen({required this.convo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text(
            convo.groupName.isEmpty ? 'Group' : convo.groupName,
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: BohoColors.terracotta
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: BohoColors.terracotta, size: 44),
                ),
                const SizedBox(height: 10),
                Text('${convo.memberIds.length} members',
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso,
                        weight: FontWeight.w600)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(context, convo),
                    icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20),
                    label: const Text('Open group chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BohoColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Members'),
          const SizedBox(height: 6),
          FutureBuilder<List<AppUser?>>(
            future: Future.wait(
                convo.memberIds.map((u) => DatabaseService().getUser(u))),
            builder: (context, snap) {
              final members =
                  (snap.data ?? const []).whereType<AppUser>().toList();
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: BohoColors.forest),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: BohoColors.tan
                            .withValues(alpha: 0.5),
                        backgroundImage: m.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(m.photoUrl)
                            : null,
                        child: m.photoUrl.isEmpty
                            ? Text(
                                m.name.isNotEmpty
                                    ? m.name[0].toUpperCase()
                                    : '?',
                                style: BohoFonts.heading(18,
                                    color: BohoColors.espresso),
                              )
                            : null,
                      ),
                      title: Text(m.name,
                          style: BohoFonts.body(15,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700)),
                      subtitle: m.location.isNotEmpty
                          ? Text(m.location,
                              style: BohoFonts.body(12,
                                  color: BohoColors.espresso))
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Shared photos'),
          const SizedBox(height: 6),
          // Placeholder until message attachments land.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: BohoColors.sand.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BohoColors.sandDark),
              ),
              child: const Icon(Icons.image_outlined,
                  color: BohoColors.cocoaSoft, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Photos shared in this group will appear here.',
                style: BohoFonts.body(12,
                    color: BohoColors.espresso)),
          ),
        ],
      ),
    );
  }
}
