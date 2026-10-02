import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/content_filter.dart';
import '../services/moderation_service.dart';
import '../services/video_call_service.dart';
import '../theme/boho_theme.dart';

/// One-to-one chat with a matched travel buddy (or a group chat when
/// [isGroup] is true).
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUid;
  final String otherName;
  final String otherPhoto;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUid,
    required this.otherName,
    required this.otherPhoto,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _initialScrollDone = false;
  bool _scrollAfterSend = false;
  late final Stream<List<ChatMessage>> _messageStream;

  @override
  void initState() {
    super.initState();
    // Hoisted: a fresh stream in build() would resubscribe (and flash
    // the loader) on every rebuild.
    _messageStream = DatabaseService().messageStream(widget.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = context.read<AuthService>().user;
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
    _controller.clear();
    _scrollAfterSend = true;
    try {
      await DatabaseService().sendMessage(widget.conversationId, me.uid, text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Scrolls to the bottom only when it makes sense: the first load
  /// (jump, so history opens at the latest message), right after the
  /// user sends (they expect to see their message), or when they are
  /// already near the bottom. Never yanks a user who scrolled up to
  /// read older messages.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (!_initialScrollDone) {
        _initialScrollDone = true;
        _scrollController.jumpTo(pos.maxScrollExtent);
        return;
      }
      final nearBottom = pos.pixels >= pos.maxScrollExtent - 150;
      if (_scrollAfterSend || nearBottom) {
        _scrollAfterSend = false;
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Handles the app-bar Report / Block menu (Apple guideline 1.2).
  Future<void> _onMenuAction(
      BuildContext context, String value, String meUid) async {
    if (value == 'report') {
      await ModerationService.fileReport(
        context,
        targetType: 'user',
        targetId: widget.otherUid,
        authorUid: widget.otherUid,
        reporterUid: meUid,
      );
    } else if (value == 'block') {
      final blocked = await ModerationService.confirmAndBlock(
        context,
        meUid: meUid,
        otherUid: widget.otherUid,
        otherName: widget.otherName,
      );
      if (blocked && context.mounted) {
        Navigator.of(context).pop(); // Back to the message list.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meUid = context.watch<AuthService>().user?.uid ?? '';
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: BohoColors.oceanMist,
              backgroundImage: widget.otherPhoto.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherPhoto)
                  : null,
              child: widget.otherPhoto.isEmpty
                  ? Text(
                      widget.otherName.isNotEmpty
                          ? widget.otherName[0].toUpperCase()
                          : '?',
                      style: BohoFonts.heading(16, color: BohoColors.forest),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(widget.otherName,
                        style: BohoFonts.heading(22,
                            color: BohoColors.espresso),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.isGroup) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.group_rounded,
                        size: 18, color: BohoColors.terracotta),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Report + block entry points (Apple guideline 1.2).
        // Hidden for group chats (report/block target a single user).
        actions: [
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_outlined,
                color: BohoColors.espresso),
            onPressed: () => VideoCallService().startCall(
              context,
              channel: widget.conversationId,
              peerName: widget.otherName,
            ),
          ),
          if (!widget.isGroup &&
              meUid.isNotEmpty &&
              meUid != widget.otherUid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: BohoColors.espresso),
              tooltip: 'More options',
              onSelected: (v) => _onMenuAction(context, v, meUid),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined,
                          color: BohoColors.terracotta, size: 20),
                      const SizedBox(width: 10),
                      Text('Report user',
                          style:
                              BohoFonts.body(15, color: BohoColors.espresso)),
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
                          style:
                              BohoFonts.body(15, color: BohoColors.espresso)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messageStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: BohoColors.forest),
                  );
                }
                final messages = snap.data ?? const [];
                _scrollToBottom();
                if (messages.isEmpty) {
                  return Center(
                    child: Text('Say hi and start planning! 👋',
                        style: BohoFonts.body(15)),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == meUid;
                    final bubble = _Bubble(message: m, mine: mine);
                    if (mine) return bubble;
                    // Long-press a traveler's message to report it
                    // (Apple guideline 1.2).
                    return GestureDetector(
                      onLongPress: () => ModerationService.fileReport(
                        context,
                        targetType: 'message',
                        targetId: m.id,
                        authorUid: m.senderId,
                        reporterUid: meUid,
                        details: 'In chat with ${widget.otherName}: ${m.text}',
                      ),
                      child: bubble,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: BohoColors.cream,
                border: Border(
                  top: BorderSide(color: BohoColors.sandDark, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: mine ? BohoColors.forest : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border:
              mine ? null : Border.all(color: BohoColors.sandDark, width: 1),
          boxShadow: [
            BoxShadow(
              color: BohoColors.cocoa.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: BohoFonts.body(
                14,
                color: mine ? Colors.white : BohoColors.cocoa,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeago.format(message.createdAt),
              style: BohoFonts.body(
                10,
                color: mine
                    ? Colors.white.withValues(alpha: 0.85)
                    : BohoColors.cocoaSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
