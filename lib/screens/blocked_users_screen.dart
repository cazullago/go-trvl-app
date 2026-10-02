import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/moderation_service.dart';
import '../theme/boho_theme.dart';

/// Settings screen listing travelers the user blocked, with an option to
/// unblock each one. Reachable from Profile -> Settings -> Blocked Users.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<Map<String, String>> _userInfo(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      return {
        'name': (data['name'] as String?) ?? 'Traveler',
        'photoUrl': (data['photoUrl'] as String?) ?? '',
      };
    } catch (_) {
      return {'name': 'Traveler', 'photoUrl': ''};
    }
  }

  Future<void> _unblock(
      BuildContext context, String meUid, String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: BohoColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Unblock $name?',
            style: BohoFonts.heading(20, color: BohoColors.espresso)),
        content: Text(
            'You will be able to see each other in matching and messages again.',
            style: BohoFonts.body(15, color: BohoColors.espresso)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Cancel',
                style: BohoFonts.body(15,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BohoColors.forest),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ModerationService.unblockUser(meUid, uid);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not unblock. Please try again.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meUid = context.watch<AuthService>().user?.uid ?? '';
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Blocked Users',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
      ),
      body: StreamBuilder<Set<String>>(
        stream: ModerationService.blockedUidsStream(meUid),
        builder: (context, snap) {
          final uids = (snap.data ?? const <String>{}).toList();
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: BohoColors.forest));
          }
          if (uids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No blocked travelers. Your island is peaceful.',
                  style: BohoFonts.body(16, color: BohoColors.espresso),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: uids.length,
            itemBuilder: (context, i) => FutureBuilder<Map<String, String>>(
              future: _userInfo(uids[i]),
              builder: (context, usnap) {
                final info =
                    usnap.data ?? const {'name': 'Traveler', 'photoUrl': ''};
                final name = info['name'] ?? 'Traveler';
                final photo = info['photoUrl'] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BohoColors.tan, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: BohoColors.tan.withValues(alpha: 0.5),
                        backgroundImage: photo.isNotEmpty
                            ? CachedNetworkImageProvider(photo)
                            : null,
                        child: photo.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: BohoFonts.heading(20,
                                    color: BohoColors.espresso),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            style: BohoFonts.body(16,
                                color: BohoColors.espresso,
                                weight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () =>
                            _unblock(context, meUid, uids[i], name),
                        child: Text('Unblock',
                            style: BohoFonts.body(14,
                                color: BohoColors.forest,
                                weight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
