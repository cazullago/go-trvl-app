// GoTRVL PH admin: user list and suspend/unsuspend actions.
//
// SECURITY MODEL: admin role is a Firebase custom claim only. Firestore
// rules enforce it server-side. The app never hardcodes credentials and
// never bypasses auth. Suspend/unsuspend writes the plain 'suspended'
// boolean on the user doc; rules decide who may write it.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Admin user management. Streams the 'users' collection (limit 100) and
/// lets an admin suspend or unsuspend accounts with a confirm dialog.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .limit(100)
        .snapshots();
  }

  Future<void> _setSuspended(
      BuildContext context, String uid, bool suspended, String name) async {
    final action = suspended ? 'suspend' : 'unsuspend';
    final ok = await adminConfirmDialog(
      context,
      '${suspended ? 'Suspend' : 'Unsuspend'} user?',
      'Are you sure you want to $action ${name.isEmpty ? 'this user' : name}?',
    );
    if (!ok || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'suspended': suspended});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update user: $e',
              style: BohoFonts.body(13, color: Colors.white)),
          backgroundColor: BohoColors.coralDeep,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: BohoColors.forest),
          );
        }
        if (snapshot.hasError) {
          return const AdminEmptyState(
            icon: Icons.cloud_off_rounded,
            message: 'Could not load users. Check your connection and rules.',
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SingleChildScrollView(
            child: AdminEmptyState(
              icon: Icons.people_outline_rounded,
              message: 'No data yet',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AdminSectionTitle('Users'),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final name = (data['name'] as String?) ??
                      (data['displayName'] as String?) ??
                      'Unknown';
                  final email =
                      (data['email'] as String?) ?? 'No email on file';
                  final suspended = (data['suspended'] as bool?) ?? false;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BohoDecor.card(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: suspended
                              ? BohoColors.terracotta.withValues(alpha: 0.2)
                              : BohoColors.forest.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: BohoFonts.heading(16,
                                color: suspended
                                    ? BohoColors.terracotta
                                    : BohoColors.forest),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: BohoFonts.heading(15),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(email,
                                  style: BohoFonts.body(12,
                                      color: BohoColors.sandMuted),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        _statusChip(suspended),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              _setSuspended(context, doc.id, !suspended, name),
                          child: Text(
                            suspended ? 'Unsuspend' : 'Suspend',
                            style: BohoFonts.body(
                              13,
                              color: suspended
                                  ? BohoColors.forest
                                  : BohoColors.terracotta,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusChip(bool suspended) {
    final color = suspended ? BohoColors.terracotta : BohoColors.forest;
    final label = suspended ? 'SUSPENDED' : 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: BohoFonts.capsLabel(10, color: color),
      ),
    );
  }
}
