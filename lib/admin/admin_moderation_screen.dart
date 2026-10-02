// GoTRVL PH admin: moderation queue for user reports.
//
// SECURITY MODEL: admin role is a Firebase custom claim only. Firestore
// rules enforce it server-side. The app never hardcodes credentials and
// never bypasses auth. Actions are: dismiss report, remove reported post,
// or suspend the reported author.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Moderation queue. Streams 'reports' where status == 'pending' and lets
/// an admin dismiss, remove the reported post, or suspend the author.
class AdminModerationScreen extends StatelessWidget {
  const AdminModerationScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingReports() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _dismiss(BuildContext context, String reportId) async {
    final ok = await adminConfirmDialog(
      context,
      'Dismiss report?',
      'This report will be marked as dismissed and removed from the queue.',
    );
    if (!ok || !context.mounted) return;
    await _updateReportStatus(context, reportId, 'dismissed');
  }

  Future<void> _removePost(
      BuildContext context, String reportId, String targetId) async {
    final ok = await adminConfirmDialog(
      context,
      'Remove post?',
      'The reported post will be deleted permanently.',
    );
    if (!ok || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(targetId)
          .delete();
      if (!context.mounted) return;
      await _updateReportStatus(context, reportId, 'actioned');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Could not remove post: $e');
    }
  }

  Future<void> _suspendAuthor(
      BuildContext context, String reportId, String authorUid) async {
    final ok = await adminConfirmDialog(
      context,
      'Suspend author?',
      'The reported author will be suspended from the app.',
    );
    if (!ok || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authorUid)
          .update({'suspended': true});
      if (!context.mounted) return;
      await _updateReportStatus(context, reportId, 'actioned');
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Could not suspend author: $e');
    }
  }

  Future<void> _updateReportStatus(
      BuildContext context, String reportId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({'status': status});
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Could not update report: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: BohoFonts.body(13, color: Colors.white)),
        backgroundColor: BohoColors.coralDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: BohoColors.forest),
          );
        }
        if (snapshot.hasError) {
          return const AdminEmptyState(
            icon: Icons.cloud_off_rounded,
            message: 'Could not load reports. Check your connection and rules.',
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SingleChildScrollView(
            child: AdminEmptyState(
              icon: Icons.flag_outlined,
              message: 'No pending reports.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AdminSectionTitle('Moderation'),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final reason =
                      (data['reason'] as String?) ?? 'No reason given';
                  final targetType =
                      (data['targetType'] as String?) ?? 'unknown';
                  final targetId = (data['targetId'] as String?) ?? '';
                  final authorUid = (data['authorUid'] as String?) ?? '';
                  final reporterUid =
                      (data['reporterUid'] as String?) ?? 'unknown';
                  final createdAt = _formatDate(data['createdAt']);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BohoDecor.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BohoColors.coralDeep
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.flag_rounded,
                                  color: BohoColors.coralDeep, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(reason, style: BohoFonts.heading(15)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Target: $targetType${targetId.isEmpty ? '' : ' $targetId'}',
                          style:
                              BohoFonts.body(12, color: BohoColors.sandMuted),
                        ),
                        Text(
                          'Reporter: $reporterUid',
                          style:
                              BohoFonts.body(12, color: BohoColors.sandMuted),
                        ),
                        Text(
                          'Reported: $createdAt',
                          style:
                              BohoFonts.body(12, color: BohoColors.sandMuted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _dismiss(context, docs[i].id),
                              child: Text('Dismiss',
                                  style: BohoFonts.body(13,
                                      weight: FontWeight.w700)),
                            ),
                            if (targetType == 'post' && targetId.isNotEmpty)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BohoColors.coralDeep,
                                ),
                                onPressed: () =>
                                    _removePost(context, docs[i].id, targetId),
                                child: Text('Remove post',
                                    style: BohoFonts.body(13,
                                        color: Colors.white,
                                        weight: FontWeight.w700)),
                              ),
                            if (authorUid.isNotEmpty)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BohoColors.terracotta,
                                ),
                                onPressed: () => _suspendAuthor(
                                    context, docs[i].id, authorUid),
                                child: Text('Suspend author',
                                    style: BohoFonts.body(13,
                                        color: Colors.white,
                                        weight: FontWeight.w700)),
                              ),
                          ],
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

  String _formatDate(dynamic value) {
    try {
      if (value is Timestamp) {
        final d = value.toDate();
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }
      if (value is String && value.isNotEmpty) return value;
    } catch (_) {}
    return 'unknown date';
  }
}
