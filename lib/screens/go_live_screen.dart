import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/live_service.dart';
import '../theme/boho_theme.dart';
import 'live_viewer_screen.dart';

const _liveCategories = [
  MapEntry('destination_tour', 'Destination Tour'),
  MapEntry('food_trip', 'Food Trip'),
  MapEntry('local_experience', 'Local Experience'),
  MapEntry('travel_tips', 'Travel Tips'),
  MapEntry('hotel_tour', 'Hotel Tour'),
  MapEntry('ask_a_local', 'Ask a Local'),
];

/// Creator setup form for starting a LIVE stream.
/// LIVE is free; virtual gifts arrive later via an approved payment provider.
class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  String _category = 'destination_tour';
  bool _goingLive = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _goLive() async {
    final me = context.read<AuthService>().user;
    if (me == null) return;
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your stream a title first.')));
      return;
    }
    setState(() => _goingLive = true);
    try {
      final streamId = await LiveService().startStream(
        LiveStream(
          id: '',
          creatorUid: me.uid,
          creatorName: me.name,
          creatorPhoto: me.photoUrl,
          title: title,
          description: _descC.text.trim(),
          category: _category,
          status: 'live',
          scheduledAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) =>
                LiveViewerScreen(streamId: streamId, isCreator: true)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _goingLive = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not start the stream. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Go Live',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: me == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Sign in to start a live stream.',
                  style: BohoFonts.body(16, color: BohoColors.espresso),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
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
                          'Stream from ${me.name.isNotEmpty ? me.name : 'your account'}',
                          style: BohoFonts.body(15,
                              color: Colors.white, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleC,
                  decoration: const InputDecoration(labelText: 'Stream title'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descC,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in _liveCategories)
                      DropdownMenuItem(value: c.key, child: Text(c.value)),
                  ],
                  onChanged: (v) =>
                      setState(() => _category = v ?? 'destination_tour'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _goingLive ? null : _goLive,
                    icon: const Icon(Icons.videocam_rounded),
                    label: Text(_goingLive ? 'Starting...' : 'Go Live'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BohoColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: BohoFonts.body(16, weight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'LIVE is free. Virtual gifts are coming soon via an '
                    'approved payment provider.',
                    style: BohoFonts.body(13,
                        color: BohoColors.espresso.withValues(alpha: 0.65)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
