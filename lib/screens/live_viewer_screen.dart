import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/content_filter.dart';
import '../services/live_service.dart';
import '../theme/boho_theme.dart';

/// Watches a live stream: stub video area, viewer count, live chat,
/// and a gifts section that is disabled until the approved payment
/// provider lands (no person-to-person transfers, ever).
class LiveViewerScreen extends StatefulWidget {
  final String streamId;
  final bool isCreator;

  const LiveViewerScreen(
      {super.key, required this.streamId, required this.isCreator});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final _chatC = TextEditingController();
  final _scroll = ScrollController();
  bool _joined = false;
  bool _sending = false;
  // Captured in initState so dispose() never touches context after the
  // widget is unmounted (context.read in dispose can throw).
  String? _myUid;
  // The in-flight join, so dispose() can chain the matching leave even
  // when the widget is torn down before the join completes. Otherwise the
  // viewer count leaks +1 on a fast open/close.
  Future<void>? _joinFuture;
  late final Stream<List<LiveStream>> _streams;
  late final Stream<List<LiveChatMessage>> _chatStream;

  @override
  void initState() {
    super.initState();
    // Hoisted: fresh stream objects in build() would resubscribe on
    // every rebuild.
    _streams = LiveService().liveStreams();
    _chatStream = LiveService().chatStream(widget.streamId);
    // Guarded for signed-in users: joining bumps the viewer count.
    _myUid = context.read<AuthService>().user?.uid;
    if (_myUid != null) {
      _joinFuture = () async {
        try {
          await LiveService().joinStream(widget.streamId);
          _joined = true;
        } catch (_) {}
      }();
    }
  }

  @override
  void dispose() {
    _chatC.dispose();
    _scroll.dispose();
    final join = _joinFuture;
    if (join != null) {
      // If the join already finished, leave now; if it is still in
      // flight, leave as soon as it lands so the count stays balanced.
      join.then((_) {
        if (_joined) {
          LiveService().leaveStream(widget.streamId).catchError((_) {});
        }
      }).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _sendChat() async {
    final me = context.read<AuthService>().user;
    final text = _chatC.text.trim();
    if (_sending || text.isEmpty) return;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to join the chat.')));
      return;
    }
    if (!ContentFilter.isAllowed(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ContentFilter.refusalMessage)),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await LiveService().sendChat(
        widget.streamId,
        LiveChatMessage(
          id: const Uuid().v4(),
          senderUid: me.uid,
          senderName: me.name,
          text: text,
          sentAt: DateTime.now(),
        ),
      );
      _chatC.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _endStream() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('End stream?',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        content: Text('Your viewers will be disconnected.',
            style: BohoFonts.body(15, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Keep going',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await LiveService().endStream(widget.streamId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Live',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: StreamBuilder<List<LiveStream>>(
        stream: _streams,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: BohoColors.forest));
          }
          LiveStream? stream;
          for (final s in snap.data ?? const <LiveStream>[]) {
            if (s.id == widget.streamId) stream = s;
          }
          if (stream == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This stream has ended.',
                  style: BohoFonts.body(16, color: BohoColors.espresso),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _content(stream);
        },
      ),
    );
  }

  Widget _content(LiveStream stream) {
    return Column(
      children: [
        _videoArea(),
        _titleRow(stream),
        Expanded(child: _chatList()),
        _giftsRow(),
        _chatInput(),
      ],
    );
  }

  /// Stub video surface. TODO: swap this box for the real video SDK
  /// (StubLiveVideoProvider is the integration point) when video lands.
  Widget _videoArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 220,
      decoration: BoxDecoration(
        color: BohoColors.espresso,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Video integration point: connect Agora/Mux here',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('LIVE',
                  style: BohoFonts.body(12,
                      color: Colors.white, weight: FontWeight.w800)),
            ),
          ),
          if (widget.isCreator)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('You are live',
                        style: BohoFonts.body(12,
                            color: Colors.white, weight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _endStream,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('End'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _titleRow(LiveStream stream) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
            child: Text(
              stream.creatorName.isNotEmpty
                  ? stream.creatorName[0].toUpperCase()
                  : '?',
              style: BohoFonts.heading(18, color: BohoColors.espresso),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stream.title,
                    style: BohoFonts.heading(17, color: BohoColors.espresso),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Text(stream.creatorName,
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso.withValues(alpha: 0.65),
                        weight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: BohoColors.forest.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_rounded,
                    size: 14, color: BohoColors.forest),
                const SizedBox(width: 4),
                Text('${stream.viewerCount}',
                    style: BohoFonts.body(12,
                        color: BohoColors.forest, weight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatList() {
    return StreamBuilder<List<LiveChatMessage>>(
      stream: _chatStream,
      builder: (context, snap) {
        final messages = snap.data ?? const <LiveChatMessage>[];
        // Follow new messages only when the viewer is already near the
        // bottom; never yank someone reading earlier chat.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients || messages.isEmpty) return;
          final pos = _scroll.position;
          if (pos.pixels >= pos.maxScrollExtent - 120) {
            _scroll.animateTo(
              pos.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
        if (messages.isEmpty) {
          return Center(
            child: Text('Say hi to kick off the chat!',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          );
        }
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: BohoFonts.body(14, color: BohoColors.espresso),
                  children: [
                    TextSpan(
                      text: '${m.senderName}: ',
                      style: BohoFonts.body(14,
                          color: BohoColors.forest, weight: FontWeight.w800),
                    ),
                    TextSpan(text: m.text),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _giftsRow() {
    final gifts = VirtualGift.samples;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: Row(
            children: [
              Text('Gifts',
                  style: BohoFonts.heading(16, color: BohoColors.espresso)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BohoColors.tan.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Coming soon',
                    style: BohoFonts.body(11,
                        color: BohoColors.espresso, weight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: gifts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = gifts[i];
              return Opacity(
                opacity: 0.55,
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BohoColors.tan, width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(g.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 2),
                      Text(g.name,
                          style: BohoFonts.body(11,
                              color: BohoColors.espresso,
                              weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${g.coinPrice} coins',
                          style:
                              BohoFonts.body(10, color: BohoColors.dustyBlue)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Text(
            "Gifts will be purchasable through the app's approved payment "
            'system. No person-to-person transfers.',
            style: BohoFonts.body(11,
                color: BohoColors.espresso.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Widget _chatInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatC,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Chat with the stream...',
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sending ? null : _sendChat,
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
    );
  }
}
