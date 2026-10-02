// GoTRVL PH admin: live stream oversight.
//
// SECURITY MODEL: admin access is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This screen assumes the
// signed-in user already carries the admin claim; the rules reject any
// write from a non-admin client.
//
// NOTE: LiveService exposes no stream of ALL streams (its list methods are
// status-filtered), so this screen queries the live_streams collection
// directly for the admin overview. Ending a stream reuses
// LiveService.endStream.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/monetization_models.dart';
import '../services/live_service.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// List live streams and let an admin end any of them.
class AdminLiveScreen extends StatelessWidget {
  const AdminLiveScreen({super.key});

  /// Newest first by scheduledAt; documents without a scheduledAt sort
  /// last. (The LiveStream model has no startedAt field, so scheduledAt is
  /// the ordering proxy.)
  Stream<List<LiveStream>> _allStreams() {
    return FirebaseFirestore.instance
        .collection('live_streams')
        .limit(50)
        .snapshots()
        .map((snap) {
      final streams =
          snap.docs.map((d) => LiveStream.fromMap(d.id, d.data())).toList();
      streams.sort((a, b) {
        final sa = a.scheduledAt;
        final sb = b.scheduledAt;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
      return streams;
    });
  }

  Future<void> _endStream(BuildContext context, LiveStream s) async {
    final confirmed = await adminConfirmDialog(
      context,
      'End stream',
      'End "${s.title}" by ${s.creatorName}? Viewers will be disconnected.',
    );
    if (!confirmed) return;
    try {
      // LiveService is stateless (Firestore is resolved lazily), so a
      // short-lived instance is fine here.
      await LiveService().endStream(s.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stream ended.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not end stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live streams')),
      body: StreamBuilder<List<LiveStream>>(
        stream: _allStreams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Could not load streams: ${snapshot.error}',
            );
          }
          final streams = snapshot.data ?? [];
          if (streams.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.videocam_off_outlined,
              message: 'No live streams yet.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: streams.length,
            itemBuilder: (context, i) {
              final s = streams[i];
              final ended = s.status == 'ended';
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
                          child: Text(
                            s.title.isEmpty ? '(Untitled stream)' : s.title,
                            style: BohoFonts.heading(16),
                          ),
                        ),
                        _StatusChip(status: s.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 16, color: BohoColors.sandMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            s.creatorName.isEmpty
                                ? 'Unknown creator'
                                : s.creatorName,
                            style: BohoFonts.body(13,
                                color:
                                    BohoColors.espresso.withValues(alpha: 0.7)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.visibility_outlined,
                            size: 16, color: BohoColors.sandMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${s.viewerCount}',
                          style: BohoFonts.body(13,
                              color:
                                  BohoColors.espresso.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    if (!ended) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _endStream(context, s),
                          icon: const Icon(Icons.stop_rounded, size: 18),
                          label: const Text('End stream'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BohoColors.terracotta,
                            side:
                                const BorderSide(color: BohoColors.terracotta),
                          ),
                        ),
                      ),
                    ],
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

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'live':
        color = BohoColors.hibiscus;
        label = 'Live';
        break;
      case 'scheduled':
        color = BohoColors.dustyBlue;
        label = 'Scheduled';
        break;
      default:
        color = BohoColors.sandMuted;
        label = status.isEmpty ? 'Unknown' : 'Ended';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style:
            BohoFonts.capsLabel(10, color: color).copyWith(letterSpacing: 1.0),
      ),
    );
  }
}
