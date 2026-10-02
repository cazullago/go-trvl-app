import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/monetization_models.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/business_service.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/ad_card.dart';

/// Listing categories used by the composer and the filter pills.
const _listingCategories = [
  ('travel_package', 'Travel Packages'),
  ('tour', 'Tours'),
  ('vehicle_rental', 'Vehicle Rentals'),
  ('other', 'Other'),
];

String _categoryLabel(String key) => _listingCategories
    .firstWhere((c) => c.$1 == key, orElse: () => ('other', key))
    .$2;

/// Travel marketplace: business listings with search, category pills,
/// featured placement, quest-stop badges, and a listing composer.
///
/// Directory only: "Book" buttons open the business's EXTERNAL link via
/// url_launcher. No booking money is ever handled in-app.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _pill = 'all'; // all | travel_package | tour | vehicle_rental
  String _query = '';
  bool _buying = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<BusinessListing>> _approvedStream() {
    try {
      return FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => BusinessListing.fromMap(d.id, d.data()))
              .toList());
    } catch (_) {
      return Stream.value(const <BusinessListing>[]);
    }
  }

  bool _featuredActive(BusinessListing b) {
    if (!b.isFeatured) return false;
    return b.featuredUntil == null || b.featuredUntil!.isAfter(DateTime.now());
  }

  List<BusinessListing> _visible(List<BusinessListing> all) {
    final q = _query.trim().toLowerCase();
    final filtered = all.where((b) {
      if (_pill != 'all' && b.category != _pill) return false;
      if (q.isEmpty) return true;
      return b.name.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q) ||
          b.provinceId.toLowerCase().contains(q);
    }).toList();
    filtered.sort((a, b) {
      final fa = _featuredActive(a) ? 0 : 1;
      final fb = _featuredActive(b) ? 0 : 1;
      return fa.compareTo(fb);
    });
    return filtered;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: BohoFonts.body(14, color: Colors.white)),
      backgroundColor: BohoColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  Future<void> _openComposer() async {
    final user = context.read<AuthService>().user;
    if (user == null) {
      _snack('Sign in to list your service. 🌴');
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListingComposer(ownerUid: user.uid),
    );
    if (created == true && mounted) {
      _snack('Listing submitted! It goes live after review. 🌺');
    }
  }

  Future<void> _book(BusinessListing b) async {
    final raw = b.website.trim();
    if (raw.isEmpty) {
      _snack(b.phone.isNotEmpty
          ? 'Contact them directly: ${b.phone} 📞'
          : 'No booking link for this listing yet.');
      return;
    }
    final url = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
    try {
      // External booking only — never an in-app transaction.
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Could not open the booking link.');
    }
  }

  // ---------- premium upsells ----------

  Future<void> _buyBusinessPremium() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) {
      _snack('Sign in first. 🌴');
      return;
    }
    setState(() => _buying = true);
    try {
      final ok = await BillingService().buyBusinessPremium();
      if (!mounted) return;
      if (ok) {
        // Fulfillment: premium tier + quest-stop status on the owner's
        // listings (verified store purchase, like traveler premium).
        final snap = await FirebaseFirestore.instance
            .collection('businesses')
            .where('ownerUid', isEqualTo: uid)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.update(d.reference,
              {'tier': BusinessTier.premium.name, 'isQuestStop': true});
        }
        await batch.commit();
        _snack(
            'Business Premium active! Your listings are pinned on top and your shop is now a quest stop. ⭐');
      } else {
        _snack('Purchase did not complete. No charge was made.');
      }
    } catch (_) {
      _snack('Something went wrong. No charge was made.');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyFeatured(BusinessListing b) async {
    setState(() => _buying = true);
    try {
      final ok = await BillingService().buyBusinessFeatured(b.id);
      if (!mounted) return;
      if (ok) {
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(b.id)
            .update({
          'isFeatured': true,
          'featuredUntil':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        });
        _snack('Featured for 30 days! Your listing is pinned on top. ★');
      } else {
        _snack('Purchase did not complete. No charge was made.');
      }
    } catch (_) {
      _snack('Something went wrong. No charge was made.');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().user?.uid;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: StreamBuilder<List<BusinessListing>>(
                stream: _approvedStream(),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return Center(
                        child: Text('Could not load listings.',
                            style: BohoFonts.body(14,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.6))));
                  }
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: BohoColors.forest));
                  }
                  final items = _visible(snap.data!);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      _searchField(),
                      const SizedBox(height: 10),
                      _pills(),
                      const SizedBox(height: 14),
                      _premiumUpsellCard(),
                      const SizedBox(height: 14),
                      const _MarketplaceAdBanner(),
                      if (uid != null) ...[
                        _myListings(uid),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          Text('All Listings', style: BohoFonts.heading(18)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: BohoColors.forest.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('${items.length}',
                                style: BohoFonts.body(12,
                                    color: BohoColors.forest,
                                    weight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        _emptyState()
                      else
                        for (final b in items)
                          _listingCard(b,
                              mine: uid != null && b.ownerUid == uid),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: BohoColors.espresso,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text('Go TRVL PH',
                style: BohoFonts.script(30, color: BohoColors.espresso)),
          ),
          ElevatedButton.icon(
            onPressed: _openComposer,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('List Service'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: BohoFonts.body(13, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      style: BohoFonts.body(15),
      decoration: InputDecoration(
        hintText: 'Search services, locations...',
        prefixIcon: const Icon(Icons.search_rounded, color: BohoColors.forest),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon:
                    const Icon(Icons.clear_rounded, color: BohoColors.espresso),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                })
            : null,
      ),
    );
  }

  Widget _pills() {
    const pills = [
      ('all', 'All'),
      ('travel_package', 'Travel Packages'),
      ('tour', 'Tours'),
      ('vehicle_rental', 'Vehicle Rentals'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = _pill == pills[i].$1;
          return InkWell(
            onTap: () => setState(() => _pill = pills[i].$1),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: on ? BohoColors.forest : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: on ? BohoColors.forest : BohoColors.tan, width: 1.4),
              ),
              child: Text(pills[i].$2,
                  style: BohoFonts.body(13,
                      color: on ? Colors.white : BohoColors.forest,
                      weight: FontWeight.w800)),
            ),
          );
        },
      ),
    );
  }

  Widget _premiumUpsellCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BohoColors.sun, BohoColors.coral],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Text('💼', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium for Business',
                    style: BohoFonts.body(15,
                        color: Colors.white, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    'Pin your listing on top AND add your shop as a quest stop for leveling.',
                    style: BohoFonts.body(12,
                        color: Colors.white, weight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _buying ? null : _buyBusinessPremium,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: BohoColors.espresso,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: BohoFonts.body(13, weight: FontWeight.w800),
            ),
            child: Text(_buying ? '…' : 'Go Premium'),
          ),
        ],
      ),
    );
  }

  Widget _myListings(String uid) {
    return StreamBuilder<List<BusinessListing>>(
      stream: BusinessService().myListings(uid),
      builder: (ctx, snap) {
        final mine = snap.data ?? const <BusinessListing>[];
        if (mine.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Your listings', style: BohoFonts.heading(16)),
            const SizedBox(height: 8),
            for (final b in mine) _listingCard(b, mine: true, showStatus: true),
          ],
        );
      },
    );
  }

  Widget _listingCard(BusinessListing b,
      {bool mine = false, bool showStatus = false}) {
    final featured = _featuredActive(b);
    final photo = b.photoUrls.isNotEmpty ? b.photoUrls.first : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: featured ? BohoColors.sun : BohoColors.tan,
            width: featured ? 2 : 1.2),
        boxShadow: [
          BoxShadow(
            color: BohoColors.cocoa.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo.
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: photo == null
                  ? const LinearGradient(
                      colors: [BohoColors.ocean, BohoColors.forest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              image: photo != null
                  ? DecorationImage(
                      image: NetworkImage(photo),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    )
                  : null,
            ),
            child: photo == null
                ? const Center(
                    child: Text('🏝️', style: TextStyle(fontSize: 44)))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (featured)
                      _badge('★ Featured', BohoColors.sun, BohoColors.espresso),
                    if (b.isQuestStop)
                      _badge('⭐ Quest Stop', BohoColors.forest, Colors.white),
                    _badge(_categoryLabel(b.category), BohoColors.oceanMist,
                        BohoColors.oceanDeep),
                    if (showStatus)
                      _badge(
                          b.status == 'approved'
                              ? '✓ Live'
                              : b.status == 'rejected'
                                  ? '✕ Rejected'
                                  : '⏳ In review',
                          b.status == 'approved'
                              ? BohoColors.leafMist
                              : BohoColors.sand,
                          BohoColors.espresso),
                  ],
                ),
                const SizedBox(height: 8),
                Text(b.name,
                    style: BohoFonts.heading(17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (b.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(b.description,
                      style: BohoFonts.body(13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (b.price.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(b.price,
                      style: BohoFonts.body(14,
                          color: BohoColors.terracotta,
                          weight: FontWeight.w800)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _book(b),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          textStyle:
                              BohoFonts.body(14, weight: FontWeight.w800),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                    if (mine && !featured) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _buying ? null : () => _buyFeatured(b),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BohoColors.espresso,
                          side: const BorderSide(
                              color: BohoColors.sun, width: 1.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          textStyle:
                              BohoFonts.body(13, weight: FontWeight.w800),
                        ),
                        child: const Text('★ Feature'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: BohoFonts.body(11, color: fg, weight: FontWeight.w800)),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: BohoColors.sand.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('🔍', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 14),
          Text('No listings found', style: BohoFonts.heading(18)),
          const SizedBox(height: 4),
          Text('Be the first to post a service!',
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openComposer,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            ),
            child: const Text('Post a Listing'),
          ),
        ],
      ),
    );
  }
}

/// Marketplace banner ad: first placement for the marketplace slot.
/// Renders nothing when the slot has no placements.
class _MarketplaceAdBanner extends StatefulWidget {
  const _MarketplaceAdBanner();

  @override
  State<_MarketplaceAdBanner> createState() => _MarketplaceAdBannerState();
}

class _MarketplaceAdBannerState extends State<_MarketplaceAdBanner> {
  late final Future<List<AdPlacement>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.value(
        AdService().placementsForSlot(AdPlacement.slotMarketplace));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdPlacement>>(
      future: _future,
      builder: (context, snap) {
        final placements = snap.data ?? const <AdPlacement>[];
        if (placements.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AdCard(placement: placements.first),
        );
      },
    );
  }
}

/// Listing composer: title, category, price, description, photos,
/// booking/contact link, and map pin (lat/lng). Writes through
/// [BusinessService.createListing] — status is forced to pending and
/// privilege fields are forced safe server-side.
class _ListingComposer extends StatefulWidget {
  final String ownerUid;
  const _ListingComposer({required this.ownerUid});

  @override
  State<_ListingComposer> createState() => _ListingComposerState();
}

class _ListingComposerState extends State<_ListingComposer> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _category = 'tour';
  final List<XFile> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    _phoneCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final ok = await PermissionService()
        .ensurePhotos(context, 'To add photos to your listing');
    if (!ok || !mounted) return;
    try {
      final picked =
          await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (picked.isNotEmpty && mounted) {
        setState(() => _photos.addAll(picked.take(6 - _photos.length)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open your photos. Please try again.')));
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your service a title first.')));
      return;
    }
    setState(() => _busy = true);
    try {
      // Upload photos first.
      final urls = <String>[];
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _photos.length; i++) {
        urls.add(await DatabaseService().uploadImage(
            File(_photos[i].path), 'businesses/${widget.ownerUid}/$ts-$i.jpg'));
      }
      final lat =
          double.tryParse(_latCtrl.text.trim().replaceAll(',', '.')) ?? 0;
      final lng =
          double.tryParse(_lngCtrl.text.trim().replaceAll(',', '.')) ?? 0;
      await BusinessService().createListing(BusinessListing(
        id: '',
        ownerUid: widget.ownerUid,
        name: title,
        category: _category,
        description: _descCtrl.text.trim(),
        photoUrls: urls,
        phone: _phoneCtrl.text.trim(),
        website: _linkCtrl.text.trim(),
        price: _priceCtrl.text.trim(),
        lat: lat,
        lng: lng,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not submit your listing. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 12),
            Text('List your service', style: BohoFonts.heading(22)),
            Text('Free listing · goes live after a quick review',
                style: BohoFonts.body(13,
                    color: BohoColors.espresso.withValues(alpha: 0.65))),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              style: BohoFonts.body(15),
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in _listingCategories)
                  DropdownMenuItem(value: c.$1, child: Text(c.$2)),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'tour'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    style: BohoFonts.body(15),
                    decoration: const InputDecoration(
                        labelText: 'Price (e.g. ₱1,500 / pax)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    style: BohoFonts.body(15),
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Contact number'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: BohoFonts.body(15),
              decoration: const InputDecoration(
                  labelText: 'Description', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _linkCtrl,
              style: BohoFonts.body(15),
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Booking / contact link (opens externally)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    style: BohoFonts.body(15),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    style: BohoFonts.body(15),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Map pin for your shop — required if you later make it a quest stop.',
                style: BohoFonts.body(12,
                    color: BohoColors.espresso.withValues(alpha: 0.6))),
            const SizedBox(height: 10),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_photos[i].path),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 88,
                            height: 88,
                            color: BohoColors.sandDark,
                            child: const Icon(Icons.image_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: BohoColors.espresso,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_photos.isEmpty
                  ? 'Add photos'
                  : 'Add more photos (${_photos.length}/6)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BohoColors.forest,
                side: const BorderSide(color: BohoColors.forest, width: 1.6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Submitting…' : 'Submit listing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
