import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/content_filter.dart';
import '../services/game_service.dart';
import '../services/live_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import 'live_viewer_screen.dart';

/// Full-screen composer opened from the center + button (or the feed's
/// GO LIVE / story tiles). `initialTab`: 0 = Post, 1 = Story, 2 = Live.
class CreatePostScreen extends StatefulWidget {
  final int initialTab;
  const CreatePostScreen({super.key, this.initialTab = 0});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  int _tab = 0;
  bool _busy = false;

  // Post tab.
  final List<XFile> _photos = [];
  final _captionC = TextEditingController();
  final _locationC = TextEditingController();
  bool _invitationOn = false;
  final _whatC = TextEditingController();
  final _whereC = TextEditingController();
  final _whoC = TextEditingController();
  final _timeC = TextEditingController();

  // Story tab.
  XFile? _storyPhoto;
  final _storyCaptionC = TextEditingController();

  // Live tab.
  final _liveTitleC = TextEditingController();
  final _liveDescC = TextEditingController();
  String _liveCategory = 'destination_tour';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _captionC.dispose();
    _locationC.dispose();
    _whatC.dispose();
    _whereC.dispose();
    _whoC.dispose();
    _timeC.dispose();
    _storyCaptionC.dispose();
    _liveTitleC.dispose();
    _liveDescC.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_busy) return false;
    switch (_tab) {
      case 0:
        return _photos.isNotEmpty;
      case 1:
        return _storyPhoto != null;
      case 2:
        return _liveTitleC.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: BohoFonts.body(14, color: Colors.white)),
        backgroundColor: error ? BohoColors.coralDeep : BohoColors.leafDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _checkText(String text) {
    if (!ContentFilter.isAllowed(text)) {
      _snack(ContentFilter.refusalMessage, error: true);
      return false;
    }
    return true;
  }

  // ------------------------------------------------------------------ POST
  Future<void> _pickPhotos() async {
    if (_busy) return;
    final ok = await PermissionService()
        .ensurePhotos(context, 'to add photos to your post');
    if (!ok) return;
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty && mounted) {
        setState(() => _photos.addAll(picked));
      }
    } catch (_) {
      _snack('Could not open your photos. Please try again.', error: true);
    }
  }

  /// Best-effort current position for the invitation's lat/lng. Never
  /// throws and never blocks posting: failures fall back to 0,0.
  Future<(double, double)> _currentLatLng() async {
    try {
      final ok = await PermissionService()
          .ensureLocation(context, 'to attach your location to the invitation');
      if (!ok) return (0.0, 0.0);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 8));
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  Future<void> _sharePost() async {
    final me = context.read<AuthService>().user;
    if (me == null || _photos.isEmpty || _busy) return;
    final caption = _captionC.text.trim();
    if (!_checkText(caption)) return;
    String what = '', where = '', who = '', time = '';
    if (_invitationOn) {
      what = _whatC.text.trim();
      where = _whereC.text.trim();
      who = _whoC.text.trim();
      time = _timeC.text.trim();
      if (what.isEmpty || where.isEmpty) {
        _snack('Add WHAT and WHERE for your invitation.', error: true);
        return;
      }
      if (!_checkText('$what $where $who $time')) return;
    }
    setState(() => _busy = true);
    try {
      final urls = <String>[];
      for (final p in _photos) {
        urls.add(await DatabaseService().uploadImage(
          File(p.path),
          'posts/${me.uid}/${const Uuid().v4()}.jpg',
        ));
      }
      String invitationId = '';
      if (_invitationOn) {
        // Cloud-Function-free geo fan-out: createInvitation also writes a
        // lightweight `invitation_alerts` doc keyed by the coarse location
        // string (the WHERE field, lowercased). NotificationsScreen matches
        // those alerts against each viewer's own location text, so invites
        // surface to travelers in the area without any server code.
        final (lat, lng) = await _currentLatLng();
        invitationId = await DatabaseService().createInvitation(
          TravelInvitation(
            id: '',
            uid: me.uid,
            userName: me.name,
            userPhoto: me.photoUrl,
            what: what,
            where: where,
            who: who,
            time: time,
            locationTag: _locationC.text.trim(),
            lat: lat,
            lng: lng,
            createdAt: DateTime.now(),
          ),
        );
      }
      await DatabaseService().createPost(
        Post(
          id: const Uuid().v4(),
          uid: me.uid,
          userName: me.name,
          userPhoto: me.photoUrl,
          imageUrl: urls.first,
          imageUrls: urls,
          caption: caption,
          locationTag: _locationC.text.trim(),
          authorPoints: me.points,
          invitationId: invitationId,
          createdAt: DateTime.now(),
        ),
      );
      await GameService().awardPost(me.uid);
      if (!mounted) return;
      _snack(_invitationOn ? 'Invite posted! ✈️' : 'Posted! 🌊');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not post. Check your connection and try again.',
          error: true);
    }
  }

  // ----------------------------------------------------------------- STORY
  Future<void> _pickStoryPhoto() async {
    if (_busy) return;
    final ok = await PermissionService()
        .ensurePhotos(context, 'to add a photo to your story');
    if (!ok) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() => _storyPhoto = picked);
      }
    } catch (_) {
      _snack('Could not open your photos. Please try again.', error: true);
    }
  }

  Future<void> _shareStory() async {
    final me = context.read<AuthService>().user;
    if (me == null || _storyPhoto == null || _busy) return;
    final caption = _storyCaptionC.text.trim();
    if (!_checkText(caption)) return;
    setState(() => _busy = true);
    try {
      final url = await DatabaseService().uploadImage(
        File(_storyPhoto!.path),
        'stories/${me.uid}/${const Uuid().v4()}.jpg',
      );
      final now = DateTime.now();
      await DatabaseService().postStory(
        Story(
          id: const Uuid().v4(),
          uid: me.uid,
          userName: me.name,
          userPhoto: me.photoUrl,
          photoUrl: url,
          caption: caption,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
        ),
      );
      await GameService().awardStory(me.uid);
      if (!mounted) return;
      _snack('Story shared! ✨');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not share your story. Please try again.', error: true);
    }
  }

  // ------------------------------------------------------------------ LIVE
  Future<void> _goLive() async {
    final me = context.read<AuthService>().user;
    if (me == null || _busy) return;
    final title = _liveTitleC.text.trim();
    if (title.isEmpty) {
      _snack('Give your stream a title first.', error: true);
      return;
    }
    if (!_checkText('$title ${_liveDescC.text.trim()}')) return;
    setState(() => _busy = true);
    try {
      final streamId = await LiveService().startStream(
        LiveStream(
          id: '',
          creatorUid: me.uid,
          creatorName: me.name,
          creatorPhoto: me.photoUrl,
          title: title,
          description: _liveDescC.text.trim(),
          category: _liveCategory,
          status: 'live',
          scheduledAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      // Real video transport needs a provider account; until then the
      // viewer screen holds the integration point (UI only).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) =>
                LiveViewerScreen(streamId: streamId, isCreator: true)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not start the stream. Please try again.', error: true);
    }
  }

  void _onShare() {
    switch (_tab) {
      case 0:
        _sharePost();
      case 1:
        _shareStory();
      case 2:
        _goLive();
    }
  }

  // ------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    // Signed-out travelers get a sign-in prompt, never a composer whose
    // Share button silently does nothing.
    final me = context.watch<AuthService>().user;
    if (me == null || me.uid.isEmpty) {
      return Scaffold(
        backgroundColor: BohoColors.cream,
        appBar: AppBar(
          backgroundColor: BohoColors.cream,
          title: Text('New Post',
              style: BohoFonts.heading(22, color: BohoColors.espresso)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📸', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('Share your adventures',
                    style: BohoFonts.display(26), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Sign in to post, share stories, and go live.',
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso.withValues(alpha: 0.65)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: BohoColors.forest,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999))),
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('New Post',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _valid ? _onShare : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: BohoColors.forest, strokeWidth: 2.5),
                    )
                  : Text('Share',
                      style: BohoFonts.body(16,
                          color: _valid
                              ? BohoColors.forest
                              : BohoColors.espresso.withValues(alpha: 0.35),
                          weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: _segmentedControl(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: switch (_tab) {
                0 => _postTab(),
                1 => _storyTab(),
                _ => _liveTab(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedControl() {
    const tabs = ['Post', 'Story', 'Live'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BohoColors.sand.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.sandDark),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: _busy ? null : () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _tab == i
                        ? [
                            BoxShadow(
                              color:
                                  BohoColors.espresso.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i == 2)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('LIVE',
                              style: BohoFonts.body(9,
                                  color: Colors.white,
                                  weight: FontWeight.w800)),
                        ),
                      Text(tabs[i],
                          style: BohoFonts.body(15,
                              color: _tab == i
                                  ? BohoColors.espresso
                                  : BohoColors.espresso.withValues(alpha: 0.55),
                              weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ POST tab
  Widget _postTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickPhotos,
          child: _photos.isEmpty
              ? AspectRatio(
                  aspectRatio: 16 / 10,
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: BohoColors.sandDeep,
                      radius: 22,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: BohoColors.sand.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 44,
                            color: BohoColors.cocoaSoft,
                          ),
                          const SizedBox(height: 8),
                          Text('Tap to add photos',
                              style: BohoFonts.body(16,
                                  color: BohoColors.cocoaSoft,
                                  weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      if (i == _photos.length) {
                        return GestureDetector(
                          onTap: _pickPhotos,
                          child: Container(
                            width: 110,
                            decoration: BoxDecoration(
                              color: BohoColors.sand.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: BohoColors.sandDeep),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                color: BohoColors.cocoaSoft, size: 30),
                          ),
                        );
                      }
                      final p = _photos[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(p.path),
                              width: 110,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text('YOUR STORY',
            style: BohoFonts.capsLabel(12, color: BohoColors.cocoaSoft)),
        const SizedBox(height: 8),
        TextField(
          controller: _captionC,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Write about your adventure...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationC,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Tag a location...',
            prefixIcon: Icon(Icons.place_outlined, color: BohoColors.coralDeep),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BohoColors.tan),
          ),
          child: Row(
            children: [
              const Icon(Icons.airplane_ticket_outlined,
                  color: BohoColors.terracotta),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turn on Invitation',
                        style: BohoFonts.body(15,
                            color: BohoColors.espresso,
                            weight: FontWeight.w700)),
                    Text('Invite others to join you',
                        style: BohoFonts.body(12, color: BohoColors.espresso)),
                  ],
                ),
              ),
              Switch(
                value: _invitationOn,
                activeTrackColor: BohoColors.terracotta,
                onChanged:
                    _busy ? null : (v) => setState(() => _invitationOn = v),
              ),
            ],
          ),
        ),
        if (_invitationOn) ...[
          const SizedBox(height: 12),
          _inviteField(
              _whatC, 'WHAT', 'e.g. Island Hopping', Icons.explore_rounded),
          const SizedBox(height: 10),
          _inviteField(
              _whereC, 'WHERE', 'e.g. Cloud 9, Siargao', Icons.place_rounded),
          const SizedBox(height: 10),
          _inviteField(_whoC, 'WHO', 'e.g. 2-3 people', Icons.group_rounded),
          const SizedBox(height: 10),
          _inviteField(
              _timeC, 'TIME', 'e.g. Tomorrow 8AM', Icons.schedule_rounded),
        ],
      ],
    );
  }

  Widget _inviteField(
      TextEditingController c, String label, String hint, IconData icon) {
    return TextField(
      controller: c,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: BohoColors.terracotta),
      ),
    );
  }

  // ----------------------------------------------------------- STORY tab
  Widget _storyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickStoryPhoto,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: _storyPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.file(
                      File(_storyPhoto!.path),
                      fit: BoxFit.cover,
                    ),
                  )
                : CustomPaint(
                    painter: _DashedBorderPainter(
                      color: BohoColors.sandDeep,
                      radius: 22,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: BohoColors.sand.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 44,
                            color: BohoColors.cocoaSoft,
                          ),
                          const SizedBox(height: 8),
                          Text('Tap to add a story photo',
                              style: BohoFonts.body(16,
                                  color: BohoColors.cocoaSoft,
                                  weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Visible for 24 hours',
                              style: BohoFonts.body(13,
                                  color: BohoColors.espresso)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _storyCaptionC,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Add a caption...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ LIVE tab
  Widget _liveTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [BohoColors.terracotta, BohoColors.espresso],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('LIVE',
                    style: BohoFonts.body(12,
                        color: Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stream to your fellow travelers',
                  style: BohoFonts.body(15,
                      color: Colors.white, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _liveTitleC,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Stream title',
            hintText: 'e.g. Sunset at Cloud 9',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liveDescC,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _liveCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(
                value: 'destination_tour', child: Text('Destination Tour')),
            DropdownMenuItem(value: 'food_trip', child: Text('Food Trip')),
            DropdownMenuItem(
                value: 'local_experience', child: Text('Local Experience')),
            DropdownMenuItem(value: 'travel_tips', child: Text('Travel Tips')),
            DropdownMenuItem(value: 'hotel_tour', child: Text('Hotel Tour')),
            DropdownMenuItem(value: 'ask_a_local', child: Text('Ask a Local')),
          ],
          onChanged: (v) =>
              setState(() => _liveCategory = v ?? 'destination_tour'),
        ),
        const SizedBox(height: 8),
        Text(
          'LIVE is free. Real video streaming needs a provider account; '
          'until then the stream page holds the integration point.',
          style: BohoFonts.body(13,
              color: BohoColors.espresso.withValues(alpha: 0.65)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Paints a rounded dashed rectangle around the photo placeholder.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    const dash = 10.0;
    const gap = 7.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
