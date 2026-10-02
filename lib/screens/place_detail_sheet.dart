import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/memory_service.dart';
import '../services/permission_service.dart';
import '../services/weather_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/place_photo.dart';

/// Place detail as a modal bottom sheet: featured label, gallery, live
/// weather, quest points, and pinned traveler memories with a composer.
///
/// Opened from the map whenever a quest place is tapped — the map always
/// zooms to the place first, then presents this sheet.
class PlaceDetailSheet extends StatefulWidget {
  final QuestPlace place;
  final AppUser user;

  const PlaceDetailSheet(
      {super.key, required this.place, required this.user});

  @override
  State<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  bool _busy = false;
  bool _done = false;
  bool _showMemoryPrompt = false;
  int _photoPage = 0;

  @override
  void initState() {
    super.initState();
    _done = widget.user.donePlaceIds.contains(widget.place.id);
  }

  Future<void> _markDone() async {
    setState(() => _busy = true);
    try {
      await GameService().awardVisit(widget.user.uid, widget.place);
      await context.read<AuthService>().refreshUser();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
      _showMemoryPrompt = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '+${widget.place.points} pts for ${widget.place.name}! Quest complete. 🎉',
          style: BohoFonts.body(14, color: Colors.white)),
      backgroundColor: BohoColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  Future<void> _directions() async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${widget.place.lat},${widget.place.lng}&travelmode=driving');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openMemoryComposer() async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MemoryComposer(place: widget.place, user: widget.user),
    );
    if (posted == true && mounted) {
      setState(() => _showMemoryPrompt = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Memory posted! +50 pts 🌺',
            style: BohoFonts.body(14, color: Colors.white)),
        backgroundColor: BohoColors.forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final gallery = placeGalleryUrls(p.id, p.name);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            // Photo gallery header.
            Stack(
              children: [
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: gallery.length,
                    onPageChanged: (i) =>
                        setState(() => _photoPage = i),
                    itemBuilder: (_, i) => PlacePhoto(
                      placeId: p.id,
                      placeName: p.name,
                      imageUrl: gallery[i],
                      width: double.infinity,
                      height: 240,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        BohoDecor.dragHandle(),
                        const SizedBox(height: 8),
                        Text('★ FEATURED PLACE',
                            style: BohoFonts.capsLabel(13,
                                color: Colors.white)),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < gallery.length; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _photoPage
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: BohoFonts.heading(26)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 16, color: BohoColors.terracotta),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                            p.address.isNotEmpty
                                ? p.address
                                : '${p.destination}, ${p.province}',
                            style: BohoFonts.body(13,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(p.blurb,
                      style: BohoFonts.body(15,
                          color: BohoColors.espresso)),
                  const SizedBox(height: 10),
                  // Live weather, always under the overview.
                  _WeatherLine(place: p),
                  const SizedBox(height: 14),
                  _filterRow(p),
                  const SizedBox(height: 14),
                  _infoCard(Icons.wb_sunny_rounded, 'Best time to visit',
                      'November to May (dry season)',
                      note:
                          'General guide for the Philippines — check local advisories before you go.',
                      BohoColors.sun),
                  const SizedBox(height: 10),
                  _infoCard(Icons.directions_rounded, 'How to get there',
                      _howToGetThere(p), BohoColors.ocean),
                  const SizedBox(height: 16),
                  _pointsBar(p),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _directions,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Get Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BohoColors.espresso,
                        side: const BorderSide(
                            color: BohoColors.espresso, width: 1.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        textStyle:
                            BohoFonts.body(15, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_showMemoryPrompt) ...[
                    const SizedBox(height: 14),
                    _memoryPrompt(),
                  ],
                  const SizedBox(height: 22),
                  _memoriesSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _howToGetThere(QuestPlace p) {
    final where = p.address.isNotEmpty ? p.address : p.name;
    return 'Make your way to $where, ${p.province}. From the nearest city '
        'or transport hub, jeepneys, buses, tricycles, or habal-habal '
        'usually cover the last stretch — ask locals for the final turn.';
  }

  Widget _filterRow(QuestPlace p) {
    const defs = [
      ('where_to_go', 'Where to Go', '🏝️'),
      ('things_to_do', 'Things to Do', '⭐'),
      ('where_to_eat', 'Where to Eat', '🍚'),
    ];
    return IgnorePointer(
      child: Wrap(
        spacing: 8,
        children: [
          for (final d in defs)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: p.filter == d.$1
                    ? BohoColors.forest
                    : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: p.filter == d.$1
                        ? BohoColors.forest
                        : BohoColors.tan,
                    width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.$3,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(d.$2,
                      style: BohoFonts.body(12,
                          color: p.filter == d.$1
                              ? Colors.white
                              : BohoColors.forest,
                          weight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(
      IconData icon, String title, String body, Color accent,
      {String note = ''}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BohoDecor.card(color: accent.withValues(alpha: 0.10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        BohoFonts.body(14, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body, style: BohoFonts.body(14)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note,
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso
                              .withValues(alpha: 0.6))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointsBar(QuestPlace p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BohoColors.forest, BohoColors.espresso],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Quest: ${p.points} pts',
                style: BohoFonts.body(13,
                    color: BohoColors.forest,
                    weight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_done || _busy) ? null : _markDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BohoColors.forest,
                disabledBackgroundColor:
                    Colors.white.withValues(alpha: 0.7),
                disabledForegroundColor: BohoColors.forest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    BohoFonts.body(15, weight: FontWeight.w800),
              ),
              child: Text(_done
                  ? '✓ Completed'
                  : _busy
                      ? 'Saving…'
                      : 'Mark as done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoryPrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BohoDecor.card(
          color: BohoColors.sun.withValues(alpha: 0.12)),
      child: Row(
        children: [
          const Text('📸', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quest complete!',
                    style: BohoFonts.body(15,
                        weight: FontWeight.w800)),
                Text('Pin a memory on this place for other travelers.',
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso
                            .withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openMemoryComposer,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
            ),
            child: const Text('Post a memory'),
          ),
        ],
      ),
    );
  }

  Widget _memoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('MEMORIES',
                    style: BohoFonts.capsLabel(13,
                        color: BohoColors.espresso))),
            TextButton(
              onPressed: _openMemoryComposer,
              child: Text('+ Post a memory',
                  style: BohoFonts.body(13,
                      color: BohoColors.forest,
                      weight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text("YOUR MEMORIES",
            style: BohoFonts.body(13, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        StreamBuilder<List<Memory>>(
          stream: MemoryService()
              .forPlace(widget.place.id, publicOnly: false),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return _memoryError();
            }
            if (!snap.hasData) {
              return const ShimmerBox(
                  height: 120,
                  borderRadius:
                      BorderRadius.all(Radius.circular(18)));
            }
            final mine = snap.data!
                .where((m) => m.uid == widget.user.uid)
                .toList();
            if (mine.isEmpty) {
              return Text('No memories yet — post the first one! 📸',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso
                          .withValues(alpha: 0.6)));
            }
            return Column(
                children: mine.map(_memoryCard).toList());
          },
        ),
        const SizedBox(height: 16),
        Text("TRAVELLER'S MEMORIES",
            style: BohoFonts.body(13, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        StreamBuilder<List<Memory>>(
          stream: MemoryService().forPlace(widget.place.id),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return _memoryError();
            }
            if (!snap.hasData) {
              return const ShimmerBox(
                  height: 120,
                  borderRadius:
                      BorderRadius.all(Radius.circular(18)));
            }
            final all = snap.data!
                .where((m) => m.uid != widget.user.uid)
                .toList();
            if (all.isEmpty) {
              return Text(
                  'No traveler memories yet. Yours could be first! 🌺',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso
                          .withValues(alpha: 0.6)));
            }
            return Column(
                children: all.map(_memoryCard).toList());
          },
        ),
      ],
    );
  }

  Widget _memoryError() => Text(
      'Could not load memories. Check your connection.',
      style: BohoFonts.body(13,
          color: BohoColors.espresso.withValues(alpha: 0.6)));

  Widget _memoryCard(Memory m) {
    final photo = m.photoUrls.isNotEmpty ? m.photoUrls.first : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BohoDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo != null)
            PlacePhoto(
              placeId: m.placeId,
              placeName: m.placeName,
              imageUrl: photo,
              height: 150,
              width: double.infinity,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.caption.isNotEmpty)
                  Text(m.caption, style: BohoFonts.body(14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('by ${m.userName}',
                          style: BohoFonts.body(12,
                              color: BohoColors.espresso
                                  .withValues(alpha: 0.6),
                              weight: FontWeight.w600)),
                    ),
                    if (!m.isPublic)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BohoColors.espresso
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(999),
                        ),
                        child: Text('Only me',
                            style: BohoFonts.body(11,
                                weight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live weather line under the place overview: shimmer while loading,
/// "⛅ 29°C · Light rain in Boracay" on success, "Weather unavailable"
/// on error, with a refresh button.
class _WeatherLine extends StatefulWidget {
  final QuestPlace place;
  const _WeatherLine({required this.place});

  @override
  State<_WeatherLine> createState() => _WeatherLineState();
}

class _WeatherLineState extends State<_WeatherLine> {
  WeatherNow? _weather;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final w = await WeatherService()
        .current(widget.place.lat, widget.place.lng);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _weather = w;
      _failed = w == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BohoColors.oceanMist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: BohoColors.ocean.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (_loading) ...[
            const ShimmerBox(
                width: 170,
                height: 18,
                borderRadius:
                    BorderRadius.all(Radius.circular(8))),
          ] else if (_failed || _weather == null) ...[
            const Text('🌥️',
                style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Weather unavailable',
                  style: BohoFonts.body(13,
                      weight: FontWeight.w600)),
            ),
          ] else ...[
            Text(_weather!.emoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_weather!.tempC.toStringAsFixed(0)}°C · ${_weather!.condition} in ${widget.place.name}',
                style: BohoFonts.body(13,
                    weight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: BohoColors.oceanDeep,
            tooltip: 'Refresh weather',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
    );
  }
}

/// Memory composer: photos (gallery picker), caption, Public/Only-me
/// toggle. Photos are for memories only — no photo-stamp logic here.
class _MemoryComposer extends StatefulWidget {
  final QuestPlace place;
  final AppUser user;
  const _MemoryComposer({required this.place, required this.user});

  @override
  State<_MemoryComposer> createState() => _MemoryComposerState();
}

class _MemoryComposerState extends State<_MemoryComposer> {
  final _captionCtrl = TextEditingController();
  final List<XFile> _photos = [];
  String _privacy = 'public';
  bool _busy = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final ok = await PermissionService()
        .ensurePhotos(context, 'To add photos to your memory');
    if (!ok || !mounted) return;
    try {
      final picked = await ImagePicker()
          .pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (picked.isNotEmpty && mounted) {
        setState(() => _photos.addAll(picked));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open your photos. Please try again.')));
    }
  }

  Future<void> _post() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a photo or write a caption first. 📸')));
      return;
    }
    setState(() => _busy = true);
    try {
      await MemoryService().postMemory(
        user: widget.user,
        place: widget.place,
        caption: caption,
        localPhotoPaths: _photos.map((f) => f.path).toList(),
        privacy: _privacy,
      );
      await GameService().awardMemory(widget.user.uid);
      await context.read<AuthService>().refreshUser();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 12),
            Text('Post a memory',
                style: BohoFonts.heading(22)),
            Text('Pinned on ${widget.place.name}',
                style: BohoFonts.body(13,
                    color: BohoColors.espresso
                        .withValues(alpha: 0.65))),
            const SizedBox(height: 14),
            // Photos.
            if (_photos.isNotEmpty)
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_photos[i].path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: BohoColors.sandDark,
                            child: const Icon(
                                Icons.image_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: BohoColors.espresso,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_photos.isEmpty
                  ? 'Add photos'
                  : 'Add more photos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BohoColors.forest,
                side: const BorderSide(
                    color: BohoColors.forest, width: 1.6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              maxLength: 280,
              style: BohoFonts.body(15),
              decoration: const InputDecoration(
                hintText:
                    'What made this place unforgettable? 🌺',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            // Privacy toggle.
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: BohoColors.tan),
              ),
              child: Row(
                children: [
                  for (final opt in const [
                    ('public', '🌐 Public'),
                    ('only_me', '🔒 Only me'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _privacy = opt.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          decoration: BoxDecoration(
                            color: _privacy == opt.$1
                                ? BohoColors.forest
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Text(opt.$2,
                                style: BohoFonts.body(14,
                                    color: _privacy == opt.$1
                                        ? Colors.white
                                        : BohoColors.espresso,
                                    weight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _post,
                child: Text(_busy
                    ? 'Posting…'
                    : 'Post memory (+50 pts)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
