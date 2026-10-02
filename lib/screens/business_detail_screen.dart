import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/monetization_models.dart';
import '../services/business_service.dart';
import '../theme/boho_theme.dart';
import 'business_hub_screen.dart';

/// Public detail page for one business listing. Listings that are not
/// approved yet show an "under review" placeholder instead of details.
class BusinessDetailScreen extends StatefulWidget {
  final String listingId;

  const BusinessDetailScreen({super.key, required this.listingId});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  // Hoisted: creating the stream in build() would resubscribe on every
  // rebuild.
  late final Stream<BusinessListing?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = BusinessService().listingStream(widget.listingId);
  }

  Future<void> _launch(String raw,
      {LaunchMode mode = LaunchMode.externalApplication}) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Business',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: StreamBuilder<BusinessListing?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: BohoColors.forest));
          }
          final listing = snap.data;
          if (listing == null || listing.status != 'approved') {
            return _underReview();
          }
          return _content(context, listing);
        },
      ),
    );
  }

  Widget _underReview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: BohoColors.sun.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 40, color: BohoColors.espresso),
            ),
            const SizedBox(height: 16),
            Text('Under review',
                style: BohoFonts.heading(22, color: BohoColors.espresso)),
            const SizedBox(height: 8),
            Text(
              'This listing is still being reviewed. '
              'It will appear here once approved.',
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.65)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, BusinessListing l) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _photos(l),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (l.isFeatured) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: BohoColors.terracotta,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Featured',
                          style: BohoFonts.body(12,
                              color: Colors.white, weight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: BohoColors.espresso,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Sponsored',
                          style: BohoFonts.body(12,
                              color: Colors.white, weight: FontWeight.w800)),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: BohoColors.forest.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(businessCategoryLabel(l.category),
                          style: BohoFonts.body(12,
                              color: BohoColors.forest,
                              weight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(l.name,
                  style: BohoFonts.script(30, color: BohoColors.espresso)),
              const SizedBox(height: 4),
              Text(businessCategoryLabel(l.category),
                  style: BohoFonts.body(14,
                      color: BohoColors.espresso.withValues(alpha: 0.65),
                      weight: FontWeight.w600)),
              if (l.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(l.description,
                    style: BohoFonts.body(15, color: BohoColors.espresso)),
              ],
              const SizedBox(height: 18),
              _actionButtons(context, l),
              if (l.tier == BusinessTier.premium) ...[
                const SizedBox(height: 22),
                Text('Special offers',
                    style: BohoFonts.heading(18, color: BohoColors.espresso)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: BohoColors.sun.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BohoColors.tan, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          color: BohoColors.terracotta, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Special offers from this business will appear here.',
                        style: BohoFonts.body(14, color: BohoColors.espresso),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photos(BusinessListing l) {
    if (l.photoUrls.isEmpty) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [BohoColors.forest, BohoColors.espresso],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.store_rounded, color: Colors.white, size: 64),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: l.photoUrls.length,
        itemBuilder: (context, i) => CachedNetworkImage(
          imageUrl: l.photoUrls[i],
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => Container(
            color: BohoColors.tan.withValues(alpha: 0.4),
            child: const Center(
                child: CircularProgressIndicator(color: BohoColors.forest)),
          ),
          errorWidget: (_, __, ___) => Container(
            color: BohoColors.tan.withValues(alpha: 0.4),
            child: const Icon(Icons.image_not_supported_rounded,
                color: BohoColors.espresso, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _actionButtons(BuildContext context, BusinessListing l) {
    return Column(
      children: [
        if (l.phone.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launch('tel:${l.phone.trim()}'),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BohoColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: BohoFonts.body(16, weight: FontWeight.w700),
              ),
            ),
          ),
        if (l.website.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _launch(l.website.trim()),
              icon: const Icon(Icons.language_rounded),
              label: const Text('Website'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BohoColors.espresso,
                side: const BorderSide(color: BohoColors.espresso, width: 1.6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: BohoFonts.body(16, weight: FontWeight.w700),
              ),
            ),
          ),
        ],
        if (l.socials.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in l.socials.entries)
                OutlinedButton.icon(
                  onPressed: () => _launch(e.value.trim()),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(_socialLabel(e.key)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BohoColors.dustyBlue,
                    side: const BorderSide(
                        color: BohoColors.dustyBlue, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    textStyle: BohoFonts.body(14, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _socialLabel(String key) {
    switch (key.toLowerCase()) {
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'x':
      case 'twitter':
        return 'X';
      case 'youtube':
        return 'YouTube';
      default:
        return key.isNotEmpty
            ? key[0].toUpperCase() + key.substring(1)
            : 'Social';
    }
  }
}
