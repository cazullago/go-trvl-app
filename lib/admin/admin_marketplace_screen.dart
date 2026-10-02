// GoTRVL PH admin: marketplace controls for approved business listings.
//
// SECURITY MODEL: admin access is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This screen assumes the
// signed-in user already carries the admin claim; the rules reject any
// write from a non-admin client.
//
// Featured and tier edits go through direct Firestore updates because
// BusinessService exposes no per-field admin methods besides setStatus.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/monetization_models.dart';
import '../theme/boho_theme.dart';
import 'widgets/admin_widgets.dart';

/// Manage approved businesses: feature them and set their tier.
class AdminMarketplaceScreen extends StatelessWidget {
  const AdminMarketplaceScreen({super.key});

  Stream<List<BusinessListing>> _approvedStream() {
    return FirebaseFirestore.instance
        .collection('businesses')
        .where('status', isEqualTo: 'approved')
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

  Future<void> _updateField(
      BuildContext context, String id, String field, Object value) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(id)
          .update({field: value});
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
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: StreamBuilder<List<BusinessListing>>(
        stream: _approvedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Could not load listings: ${snapshot.error}',
            );
          }
          final listings = snapshot.data ?? [];
          if (listings.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.storefront_outlined,
              message: 'No approved businesses yet.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: listings.length,
            itemBuilder: (context, i) {
              final l = listings[i];
              final isPremium = l.tier == BusinessTier.premium;
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
                        IconButton(
                          tooltip: l.isFeatured
                              ? 'Remove featured'
                              : 'Mark featured',
                          onPressed: () => _updateField(
                              context, l.id, 'isFeatured', !l.isFeatured),
                          icon: Icon(
                            l.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: l.isFeatured
                                ? BohoColors.sun
                                : BohoColors.sandMuted,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          l.category,
                          style: BohoFonts.capsLabel(11,
                              color: BohoColors.sandMuted),
                        ),
                        const SizedBox(width: 10),
                        _TierChip(isPremium: isPremium),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Tier',
                            style: BohoFonts.body(13,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.7))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: BohoColors.cream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BohoColors.sandDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: isPremium ? 'premium' : 'free',
                              items: const [
                                DropdownMenuItem(
                                    value: 'free', child: Text('Free')),
                                DropdownMenuItem(
                                    value: 'premium', child: Text('Premium')),
                              ],
                              style: BohoFonts.body(13),
                              onChanged: (value) {
                                if (value != null) {
                                  _updateField(context, l.id, 'tier', value);
                                }
                              },
                            ),
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
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final bool isPremium;

  const _TierChip({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final color = isPremium ? BohoColors.terracotta : BohoColors.dustyBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPremium ? 'Premium' : 'Free',
        style:
            BohoFonts.capsLabel(10, color: color).copyWith(letterSpacing: 1.0),
      ),
    );
  }
}
