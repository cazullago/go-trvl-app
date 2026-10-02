// GoTRVL PH admin: content overview and business approval queue.
//
// SECURITY MODEL: admin access is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This screen assumes the
// signed-in user already carries the admin claim; the rules reject any
// write from a non-admin client.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/monetization_models.dart';
import '../services/business_service.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Travel data overview plus the pending business approval queue.
///
/// Destinations and provinces are bundled JSON assets and are read-only
/// here; only business listings can be approved or rejected from this
/// screen.
class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _TravelDataCard(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AdminSectionTitle('Approval queue'),
          ),
          Expanded(child: _PendingQueue()),
        ],
      ),
    );
  }
}

/// Read-only explainer: travel data ships inside the app bundle, not
/// Firestore, so the dashboard cannot edit it live.
class _TravelDataCard extends StatelessWidget {
  const _TravelDataCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BohoDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: BohoColors.forest, size: 24),
              const SizedBox(width: 10),
              Text('App travel data', style: BohoFonts.heading(17)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Destinations and provinces ship as bundled JSON assets '
            '(assets/data/destinations_*.json and assets/data/provinces.json). '
            'They update only when a new app release is published, so this '
            'dashboard cannot edit them live. To change travel data, edit '
            'the asset files and ship a new build.',
            style: BohoFonts.body(14,
                color: BohoColors.espresso.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _PendingQueue extends StatelessWidget {
  _PendingQueue();

  final BusinessService _businessService = BusinessService();

  Stream<List<BusinessListing>> _pendingStream() {
    return FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'pending')
        .limit(100)
        .snapshots()
        .map((snap) {
      final listings = snap.docs
          .map((d) => BusinessListing.fromMap(d.id, d.data()))
          .toList();
      listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return listings;
    });
  }

  Future<void> _setStatus(
      BuildContext context, String id, String name, String status) async {
    if (status == 'rejected') {
      final confirmed = await adminConfirmDialog(
        context,
        'Reject listing',
        'Reject "$name"? It will stay hidden from the directory.',
      );
      if (!confirmed) return;
    }
    try {
      await _businessService.setStatus(id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '"$name" ${status == 'approved' ? 'approved' : 'rejected'}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessListing>>(
      stream: _pendingStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminEmptyState(
            icon: Icons.error_outline_rounded,
            message: 'Could not load the queue: ${snapshot.error}',
          );
        }
        final listings = snapshot.data ?? [];
        if (listings.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.check_circle_outline_rounded,
            message: 'Nothing waiting. All listings have been reviewed.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: listings.length,
          itemBuilder: (context, i) {
            final l = listings[i];
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
                        child: Text(l.name, style: BohoFonts.heading(16)),
                      ),
                      _Chip(
                        label: l.category,
                        color: BohoColors.dustyBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted ${_formatDate(l.createdAt)}',
                    style: BohoFonts.capsLabel(11, color: BohoColors.sandMuted),
                  ),
                  if (l.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      l.description,
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso.withValues(alpha: 0.75)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _setStatus(context, l.id, l.name, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BohoColors.terracotta,
                            side:
                                const BorderSide(color: BohoColors.terracotta),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _setStatus(context, l.id, l.name, 'approved'),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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

String _formatDate(DateTime d) {
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
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
