import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/game_service.dart';
import '../services/memory_service.dart';
import '../services/quest_service.dart';
import '../services/synthetic_quests.dart';
import '../theme/boho_theme.dart';
import '../widgets/place_photo.dart';
import 'city_list_screen.dart';
import 'destination_detail_screen.dart';
import 'quest_opener.dart';

/// Province explore page (YouWare Abra flow):
/// hero photo, Overview, Best Time, Explore grid (Where to Go = the
/// province's cities & municipalities), province points + Mark as done,
/// and Your / Travellers memories.
class ProvinceExploreScreen extends StatefulWidget {
  final Province province;

  const ProvinceExploreScreen({super.key, required this.province});

  @override
  State<ProvinceExploreScreen> createState() => _ProvinceExploreScreenState();
}

class _ProvinceExploreScreenState extends State<ProvinceExploreScreen> {
  bool _marking = false;

  Province get _p => widget.province;

  @override
  Widget build(BuildContext context) {
    final qp = SyntheticQuests.province(_p);
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: BohoColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_p.name,
            style: BohoFonts.display(26, color: BohoColors.espresso)),
      ),
      body: Consumer<AuthService>(
        builder: (context, auth, _) {
          final user = auth.user;
          final done =
              user?.donePlaceIds.contains(qp.id) ?? false;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _overview(),
                    const SizedBox(height: 18),
                    _bestTime(),
                    const SizedBox(height: 18),
                    _exploreGrid(),
                    const SizedBox(height: 18),
                    _pointsRow(qp, user, done),
                    const SizedBox(height: 22),
                    _memories(qp, user),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlacePhoto(
              placeId: 'prov:${_p.id}',
              placeName: _p.name,
              fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 16,
            child: Text(_p.name,
                style: BohoFonts.display(40, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        const SizedBox(height: 6),
        if (_p.tagline.isNotEmpty)
          Text(_p.tagline,
              style: const TextStyle(
                  fontSize: 15, fontStyle: FontStyle.italic)),
        const SizedBox(height: 4),
        Text(
          'Welcome to ${_p.name}, a beautiful province in the Philippines. ${_p.description}',
          style: BohoFonts.body(14,
              color: BohoColors.espresso.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _bestTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Best Time',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        const SizedBox(height: 6),
        Text('Dry season (November to April) is generally the best time to explore ${_p.name}.',
            style: BohoFonts.body(14)),
      ],
    );
  }

  Widget _exploreGrid() {
    final tiles = [
      _ExploreTile('🏝️', 'Where to Go', () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CityListScreen(province: _p)));
      }),
      _ExploreTile('🏄', 'Things to Do', () => _openFilter('things_to_do')),
      _ExploreTile('🍽️', 'Where to Eat', () => _openFilter('where_to_eat')),
      _ExploreTile('🏨', 'Where to Stay', _openGuides),
      _ExploreTile('🛍️', 'Where to Buy', _openGuides),
      _ExploreTile('🚐', 'How to Get Around', _openGuides),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explore',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: tiles.length,
          itemBuilder: (_, i) {
            final t = tiles[i];
            return GestureDetector(
              onTap: t.onTap,
              child: Container(
                decoration: BohoDecor.card(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Text(t.label,
                        style: BohoFonts.body(15,
                            weight: FontWeight.w800)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openFilter(String filter) {
    final quests = QuestService()
        .all
        .where((q) => q.province == _p.name && q.filter == filter)
        .toList();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FilterQuestScreen(
            province: _p, filter: filter, quests: quests)));
  }

  void _openGuides() {
    final guides = DataService().destinationsByProvince(_p.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 10),
            Text('Travel guides in ${_p.name}',
                style: BohoFonts.heading(20)),
            const SizedBox(height: 10),
            if (guides.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Guides for ${_p.name} are coming soon. 🌺',
                    style: BohoFonts.body(14)),
              )
            else
              ...guides.map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('⭐',
                        style: TextStyle(fontSize: 24)),
                    title: Text(d.name,
                        style: BohoFonts.body(15,
                            weight: FontWeight.w800)),
                    subtitle: Text(d.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BohoFonts.body(12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: BohoColors.tan),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              DestinationDetailScreen(destination: d)));
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _pointsRow(QuestPlace qp, AppUser? user, bool done) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BohoDecor.card(),
      child: Row(
        children: [
          Expanded(
            child: Text('Points: ${qp.points}',
                style: BohoFonts.body(20,
                    color: BohoColors.terracotta,
                    weight: FontWeight.w800)),
          ),
          if (done)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: BohoColors.leaf.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: BohoColors.leaf, size: 18),
                  const SizedBox(width: 6),
                  Text('Completed',
                      style: BohoFonts.body(14,
                          color: BohoColors.leaf,
                          weight: FontWeight.w800)),
                ],
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: _marking || user == null
                  ? null
                  : () => _markDone(qp, user),
              child: _marking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Mark as done'),
            ),
        ],
      ),
    );
  }

  Future<void> _markDone(QuestPlace qp, AppUser user) async {
    setState(() => _marking = true);
    await GameService().awardVisit(user.uid, qp);
    await context.read<AuthService>().refreshUser();
    if (!mounted) return;
    setState(() => _marking = false);
    _snack('Explored ${_p.name}! +${qp.points} pts 🎉');
    _memoryPrompt(qp, user);
  }

  void _memoryPrompt(QuestPlace qp, AppUser user) {
    final caption = TextEditingController();
    var privacy = 'public';
    showDialog(
      context: context,
      builder: (dlg) => StatefulBuilder(
        builder: (dlg2, setDlg) => AlertDialog(
          backgroundColor: BohoColors.cream,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Share a memory? 📸',
              style: BohoFonts.heading(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caption,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'How was ${_p.name}?',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: privacy == 'public',
                    onSelected: (_) => setDlg(() => privacy = 'public'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Only me'),
                    selected: privacy == 'only_me',
                    onSelected: (_) => setDlg(() => privacy = 'only_me'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlg).pop(),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = caption.text.trim();
                Navigator.of(dlg).pop();
                if (text.isEmpty) return;
                try {
                  await MemoryService().postMemory(
                    user: user,
                    place: qp,
                    caption: text,
                    localPhotoPaths: const [],
                    privacy: privacy,
                  );
                  await GameService().awardMemory(user.uid);
                  await context.read<AuthService>().refreshUser();
                  if (mounted) _snack('Memory posted! 📸');
                } catch (e) {
                  if (mounted) _snack('Could not post memory.');
                }
              },
              child: const Text('Post memory'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memories(QuestPlace qp, AppUser? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Memories',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        const SizedBox(height: 8),
        Text('Your Memories',
            style: BohoFonts.body(15, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        StreamBuilder<List<Memory>>(
          stream:
              MemoryService().forPlace(qp.id, publicOnly: false),
          builder: (ctx, snap) {
            if (snap.hasError || !snap.hasData) {
              return Text(
                  'No memories yet. Mark as done to add one!',
                  style: BohoFonts.body(14,
                          color: BohoColors.espresso
                              .withValues(alpha: 0.6))
                      .copyWith(fontStyle: FontStyle.italic));
            }
            final mine = snap.data!
                .where((m) => m.uid == user?.uid)
                .toList();
            if (mine.isEmpty) {
              return Text(
                  'No memories yet. Mark as done to add one!',
                  style: BohoFonts.body(14,
                          color: BohoColors.espresso
                              .withValues(alpha: 0.6))
                      .copyWith(fontStyle: FontStyle.italic));
            }
            return Column(
                children: mine.map(_memoryCard).toList());
          },
        ),
        const SizedBox(height: 14),
        Text('Travellers Memories',
            style: BohoFonts.body(15, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        StreamBuilder<List<Memory>>(
          stream: MemoryService().forPlace(qp.id),
          builder: (ctx, snap) {
            if (snap.hasError || !snap.hasData) {
              return Text(
                  'No memories from other travellers yet.',
                  style: BohoFonts.body(14,
                          color: BohoColors.espresso
                              .withValues(alpha: 0.6))
                      .copyWith(fontStyle: FontStyle.italic));
            }
            final others = snap.data!
                .where((m) => m.uid != user?.uid)
                .toList();
            if (others.isEmpty) {
              return Text(
                  'No memories from other travellers yet.',
                  style: BohoFonts.body(14,
                          color: BohoColors.espresso
                              .withValues(alpha: 0.6))
                      .copyWith(fontStyle: FontStyle.italic));
            }
            return Column(
                children: others.map(_memoryCard).toList());
          },
        ),
      ],
    );
  }

  Widget _memoryCard(Memory m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BohoDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.userName,
                    style: BohoFonts.body(13,
                        weight: FontWeight.w800)),
              ),
              if (!m.isPublic)
                Text('🔒 only me',
                    style: BohoFonts.body(11,
                        color: BohoColors.espresso
                            .withValues(alpha: 0.55))),
            ],
          ),
          if (m.caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.caption, style: BohoFonts.body(14)),
          ],
          if (m.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: m.photoUrls.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(m.photoUrls[i],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox()),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: BohoFonts.body(14, color: Colors.white)),
      backgroundColor: BohoColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }
}

class _ExploreTile {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  _ExploreTile(this.emoji, this.label, this.onTap);
}

/// Simple list of authored quests for a province + filter
/// (province Things to Do / Where to Eat).
class _FilterQuestScreen extends StatelessWidget {
  final Province province;
  final String filter;
  final List<QuestPlace> quests;

  const _FilterQuestScreen(
      {required this.province, required this.filter, required this.quests});

  @override
  Widget build(BuildContext context) {
    final title =
        filter == 'things_to_do' ? '🏄 Things to Do' : '🍽️ Where to Eat';
    final allPlaces = [...QuestService().all];
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: BohoColors.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: BohoFonts.display(24, color: BohoColors.espresso)),
      ),
      body: quests.isEmpty
          ? Center(
              child: Text(
                  'No ${title.substring(2)} stops listed for ${province.name} yet. 🌺',
                  style: BohoFonts.body(15),
                  textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: quests.length,
              itemBuilder: (_, i) {
                final q = quests[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => QuestOpener.open(context, q,
                        allPlaces: allPlaces),
                    child: Container(
                      decoration: BohoDecor.card(),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(q.name,
                                    style: BohoFonts.body(15,
                                        weight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(q.blurb,
                                    style: BohoFonts.body(12,
                                        color: BohoColors.espresso
                                            .withValues(alpha: 0.65)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${q.points} pts',
                                    style: BohoFonts.body(13,
                                        color: BohoColors.terracotta,
                                        weight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => QuestOpener.open(
                                context, q,
                                allPlaces: allPlaces),
                            child: Text('View Details →',
                                style: BohoFonts.body(12,
                                    color: BohoColors.dustyBlue,
                                    weight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
