// GoTRVL PH admin: announcements.
//
// SECURITY MODEL: admin access is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. The matching rules for
// the announcements collection are: public read, admin write. This screen
// assumes the signed-in user already carries the admin claim.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Audience targets for an announcement.
const Map<String, String> _audiences = {
  'all': 'All',
  'users': 'Users',
  'businesses': 'Businesses',
};

/// Create, list and delete app announcements.
class AdminAnnouncementsScreen extends StatelessWidget {
  const AdminAnnouncementsScreen({super.key});

  Stream<List<_Announcement>> _announcementsStream() {
    return FirebaseFirestore.instance
        .collection('announcements')
        .limit(100)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(_Announcement.fromDoc).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> _delete(BuildContext context, _Announcement a) async {
    final confirmed = await adminConfirmDialog(
      context,
      'Delete announcement',
      'Delete "${a.title}"? This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(a.id)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _openCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: StreamBuilder<List<_Announcement>>(
        stream: _announcementsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Could not load announcements: ${snapshot.error}',
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.campaign_outlined,
              message: 'No announcements yet. Tap New to post one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BohoDecor.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.title, style: BohoFonts.heading(16)),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, a),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: BohoColors.terracotta),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _AudienceChip(audience: a.audience),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(a.createdAt),
                          style: BohoFonts.capsLabel(11,
                              color: BohoColors.sandMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.body,
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso.withValues(alpha: 0.75)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Announcement {
  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;

  const _Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
  });

  factory _Announcement.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return _Announcement(
      id: doc.id,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      audience: (m['audience'] as String?) ?? 'all',
      createdAt: dateTimeOf(m['createdAt']),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String audience;

  const _AudienceChip({required this.audience});

  @override
  Widget build(BuildContext context) {
    const color = BohoColors.forest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _audiences[audience] ?? audience,
        style:
            BohoFonts.capsLabel(10, color: color).copyWith(letterSpacing: 1.0),
      ),
    );
  }
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _audience = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are both required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'body': body,
        'audience': _audience,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BohoColors.creamSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BohoColors.sandDark),
      ),
      title: Text('New announcement', style: BohoFonts.heading(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              style: BohoFonts.body(14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Body'),
              maxLines: 4,
              style: BohoFonts.body(14),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: _audiences.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _audience = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final minute = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} $hour:$minute $ampm';
}
