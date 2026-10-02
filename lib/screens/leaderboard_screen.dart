import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/boho_theme.dart';

/// Island leaderboard: top travelers by points, with the current
/// user's row highlighted.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const _medals = ['\u{1F947}', '\u{1F948}', '\u{1F949}'];

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthService>().user?.uid;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Island Leaderboard',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(
              'Earn points by marking places done on the map.',
              style: BohoFonts.body(14, color: BohoColors.cocoaSoft),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: DatabaseService().leaderboard(limit: 50),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: BohoColors.forest));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Could not load the leaderboard.',
                        style: BohoFonts.body(15)),
                  );
                }
                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return Center(
                    child: Text('No travelers on the board yet.',
                        style: BohoFonts.body(15)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return _row(u, i, u.uid == myUid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppUser user, int index, bool isMe) {
    final level = user.level;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          isMe ? BohoDecor.card(color: BohoColors.coralMist) : BohoDecor.card(),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Center(child: _rank(index)),
          ),
          const SizedBox(width: 10),
          _avatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.name,
                          style: BohoFonts.body(16, weight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BohoColors.forest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('you',
                            style: BohoFonts.body(11,
                                color: Colors.white, weight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${level.emoji} ${level.name}',
                    style: BohoFonts.body(13, color: BohoColors.cocoaSoft)),
              ],
            ),
          ),
          Text('${user.points} pts',
              style: BohoFonts.body(16,
                  color: BohoColors.coralDeep, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _rank(int index) {
    if (index < 3) {
      return Text(_medals[index], style: const TextStyle(fontSize: 26));
    }
    return Text('${index + 1}',
        style: BohoFonts.body(17, weight: FontWeight.w800));
  }

  Widget _avatar(AppUser user) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: BohoColors.tan,
      backgroundImage: user.photoUrl.isNotEmpty
          ? CachedNetworkImageProvider(user.photoUrl)
          : null,
      child: user.photoUrl.isEmpty
          ? Text(initial,
              style: BohoFonts.heading(24, color: BohoColors.forest))
          : null,
    );
  }
}
