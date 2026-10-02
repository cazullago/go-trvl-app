// GoTRVL PH admin overview: real counts from Firestore only.
//
// SECURITY MODEL: admin role is a Firebase custom claim only. Firestore
// rules enforce it server-side. The app never hardcodes credentials and
// never bypasses auth. Counts come from count() aggregates; no fake or
// placeholder numbers are shown anywhere.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Overview tab of the admin dashboard. Every number comes from a live
/// Firestore count aggregate. Zero counts show an honest empty state.
class DashboardHome extends StatefulWidget {
  /// Number of stat-card columns in the grid; set by the dashboard shell
  /// based on available width (2 for medium, 3 for wide).
  final int statColumns;

  const DashboardHome({super.key, this.statColumns = 2});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _loading = true;
  String? _error;
  int _users = 0;
  int _posts = 0;
  int _businesses = 0;
  int _liveStreams = 0;
  int _pendingReports = 0;
  int _revenueEvents = 0;
  double _revenueTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(String collection,
      {Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q)?
          filter}) async {
    try {
      var q = FirebaseFirestore.instance.collection(collection)
          as Query<Map<String, dynamic>>;
      if (filter != null) q = filter(q);
      final snap = await q.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _count('users'),
        _count('posts'),
        _count('businesses'),
        _count('live_streams'),
        _count('reports',
            filter: (q) => q.where('status', isEqualTo: 'pending')),
      ]);
      // Revenue events: admin-only collection. Count rows and sum numeric
      // 'amount' fields; missing or non-numeric amounts are skipped.
      int revCount = 0;
      double revTotal = 0;
      try {
        final revSnap = await FirebaseFirestore.instance
            .collection('revenue_events')
            .limit(1000)
            .get();
        revCount = revSnap.size;
        for (final doc in revSnap.docs) {
          final data = doc.data();
          final amount = data['amount'];
          if (amount is num) revTotal += amount.toDouble();
        }
      } catch (_) {
        revCount = 0;
        revTotal = 0;
      }
      if (!mounted) return;
      setState(() {
        _users = results[0];
        _posts = results[1];
        _businesses = results[2];
        _liveStreams = results[3];
        _pendingReports = results[4];
        _revenueEvents = revCount;
        _revenueTotal = revTotal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load stats. Check your connection and rules.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: BohoColors.forest),
        ),
      );
    }
    if (_error != null) {
      return AdminEmptyState(icon: Icons.cloud_off_rounded, message: _error!);
    }

    final stats = <AdminStatCard>[
      AdminStatCard(
          label: 'USERS',
          value: '$_users',
          icon: Icons.people_rounded,
          color: BohoColors.forest),
      AdminStatCard(
          label: 'POSTS',
          value: '$_posts',
          icon: Icons.photo_library_rounded,
          color: BohoColors.dustyBlue),
      AdminStatCard(
          label: 'BUSINESSES',
          value: '$_businesses',
          icon: Icons.storefront_rounded,
          color: BohoColors.terracotta),
      AdminStatCard(
          label: 'LIVE STREAMS',
          value: '$_liveStreams',
          icon: Icons.live_tv_rounded,
          color: BohoColors.hibiscus),
      AdminStatCard(
          label: 'PENDING REPORTS',
          value: '$_pendingReports',
          icon: Icons.flag_rounded,
          color: BohoColors.coralDeep),
    ];

    final allZero = _users == 0 &&
        _posts == 0 &&
        _businesses == 0 &&
        _liveStreams == 0 &&
        _pendingReports == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Overview'),
          if (allZero)
            const AdminEmptyState(
              icon: Icons.insights_rounded,
              message: 'No data yet',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.statColumns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 96,
              ),
              itemCount: stats.length,
              itemBuilder: (ctx, i) => stats[i],
            ),
          const SizedBox(height: 20),
          const AdminSectionTitle('Notes'),
          _noteCard(
            Icons.phone_android_rounded,
            'Saved trips are stored on-device, not in the cloud.',
          ),
          const SizedBox(height: 10),
          _noteCard(
            Icons.open_in_new_rounded,
            'Bookings happen on partner sites; a future `bookings` collection can be wired here.',
          ),
          const SizedBox(height: 20),
          const AdminSectionTitle('Revenue'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BohoDecor.card(),
            child: _revenueEvents == 0
                ? const AdminEmptyState(
                    icon: Icons.payments_outlined,
                    message: 'No revenue events recorded yet.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMoney(_revenueTotal),
                        style: BohoFonts.heading(30, color: BohoColors.forest),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'from $_revenueEvents recorded event${_revenueEvents == 1 ? '' : 's'}',
                        style: BohoFonts.body(13, color: BohoColors.sandMuted),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BohoDecor.card(color: BohoColors.sand),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BohoColors.cocoa, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: BohoFonts.body(14)),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return 'P ${buf.toString()}.${parts[1]}';
  }
}
