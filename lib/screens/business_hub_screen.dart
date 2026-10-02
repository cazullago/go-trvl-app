import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/data_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import 'business_detail_screen.dart';
import 'business_feature_screen.dart';

const _businessCategories = [
  MapEntry('hotel', 'Hotel'),
  MapEntry('resort', 'Resort'),
  MapEntry('restaurant', 'Restaurant'),
  MapEntry('cafe', 'Cafe'),
  MapEntry('tour_operator', 'Tour Operator'),
  MapEntry('attraction', 'Attraction'),
  MapEntry('activity', 'Activity'),
  MapEntry('other', 'Other'),
];

String businessCategoryLabel(String key) => _businessCategories
    .firstWhere((e) => e.key == key,
        orElse: () => const MapEntry('other', 'Other'))
    .value;

/// "For Business": a signed-in business owner manages listings, compares
/// Free vs Premium tiers, and can ask about featured placement.
/// No checkout UI here: featuring is arranged manually for now.
class BusinessHubScreen extends StatefulWidget {
  const BusinessHubScreen({super.key});

  @override
  State<BusinessHubScreen> createState() => _BusinessHubScreenState();
}

class _BusinessHubScreenState extends State<BusinessHubScreen> {
  bool _showForm = false;
  bool _submitting = false;

  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _phoneC = TextEditingController();
  final _webC = TextEditingController();
  String _category = 'hotel';
  String? _provinceId;

  @override
  void initState() {
    super.initState();
    DataService().load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _phoneC.dispose();
    _webC.dispose();
    super.dispose();
  }

  Future<void> _submit(String uid) async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please give your business a name.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await BusinessService().createListing(
        BusinessListing(
          id: '',
          ownerUid: uid,
          name: name,
          category: _category,
          description: _descC.text.trim(),
          phone: _phoneC.text.trim(),
          website: _webC.text.trim(),
          provinceId: _provinceId ?? '',
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _showForm = false;
        _nameC.clear();
        _descC.clear();
        _phoneC.clear();
        _webC.clear();
        _category = 'hotel';
        _provinceId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Submitted. We'll review it soon.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('For Business',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Sign in to manage your business listings.',
                  style: BohoFonts.body(16, color: BohoColors.espresso),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _heroCard(),
                const SizedBox(height: 22),
                SectionHeader(title: 'My listings'),
                const SizedBox(height: 8),
                _listings(user.uid),
                const SizedBox(height: 18),
                _createListingButton(user.uid),
                if (_showForm) _createForm(user.uid),
                const SizedBox(height: 22),
                SectionHeader(title: 'Free vs Premium'),
                const SizedBox(height: 8),
                _tierCards(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const BusinessFeatureScreen()),
                    ),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Feature your business'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BohoColors.terracotta,
                      side: const BorderSide(
                          color: BohoColors.terracotta, width: 1.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: BohoFonts.body(16, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BohoColors.forest, BohoColors.espresso],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Put your business on the map',
              style: BohoFonts.script(26, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Free basic listings for Philippine travel businesses. '
            'Upgrade to Premium for more photos, special offers, '
            'and analytics.',
            style:
                BohoFonts.body(14, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _listings(String uid) => _MyListings(uid: uid);

  static Widget _statusChip(String status) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'approved':
        bg = BohoColors.forest.withValues(alpha: 0.14);
        fg = BohoColors.forest;
        label = 'Approved';
      case 'rejected':
        bg = const Color(0xFFC0392B).withValues(alpha: 0.12);
        fg = const Color(0xFFC0392B);
        label = 'Rejected';
      case 'pending':
      default:
        bg = BohoColors.sun.withValues(alpha: 0.35);
        fg = BohoColors.espresso;
        label = 'Under review';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label,
          style: BohoFonts.body(11, color: fg, weight: FontWeight.w800)),
    );
  }

  Widget _createListingButton(String uid) {
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        label: _showForm ? 'Hide form' : 'Create listing',
        icon: _showForm ? Icons.close_rounded : Icons.add_rounded,
        onPressed: () => setState(() => _showForm = !_showForm),
      ),
    );
  }

  Widget _createForm(String uid) {
    final provinces = DataService().provinces;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New listing',
              style: BohoFonts.heading(18, color: BohoColors.espresso)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameC,
            decoration: const InputDecoration(labelText: 'Business name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in _businessCategories)
                DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'hotel'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descC,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneC,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _webC,
            decoration: const InputDecoration(labelText: 'Website'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _provinceId,
            decoration: const InputDecoration(labelText: 'Province'),
            items: [
              for (final p in provinces)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _provinceId = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(uid),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit for review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierCards() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _tierCard(
                'Free', BusinessTier.freeFeatures, BohoColors.forest, false)),
        const SizedBox(width: 12),
        Expanded(
            child: _tierCard('Premium', BusinessTier.premiumFeatures,
                BohoColors.terracotta, true)),
      ],
    );
  }

  Widget _tierCard(
      String title, List<String> features, Color accent, bool star) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (star)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.star_rounded,
                      color: BohoColors.terracotta, size: 20),
                ),
              Text(title,
                  style: BohoFonts.heading(17, color: BohoColors.espresso)),
            ],
          ),
          const SizedBox(height: 10),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f,
                        style: BohoFonts.body(13, color: BohoColors.espresso)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Owner's listing list with its stream hoisted: creating the stream in
/// build() would resubscribe on every rebuild of the hub.
class _MyListings extends StatefulWidget {
  final String uid;
  const _MyListings({required this.uid});

  @override
  State<_MyListings> createState() => _MyListingsState();
}

class _MyListingsState extends State<_MyListings> {
  late Stream<List<BusinessListing>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = BusinessService().myListings(widget.uid);
  }

  @override
  void didUpdateWidget(covariant _MyListings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _stream = BusinessService().myListings(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessListing>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: BohoColors.forest)),
          );
        }
        final listings = snap.data ?? [];
        if (listings.isEmpty) {
          return const EmptyState(
            text: 'No listings yet. Create your first free listing below.',
            icon: Icons.business_center_rounded,
          );
        }
        return Column(
          children: [
            for (final l in listings)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BohoColors.tan, width: 1.2),
                ),
                child: ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: BohoColors.forest.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.store_rounded,
                        color: BohoColors.forest),
                  ),
                  title: Text(l.name,
                      style: BohoFonts.body(15,
                          color: BohoColors.espresso, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(businessCategoryLabel(l.category),
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso.withValues(alpha: 0.6))),
                  trailing: _BusinessHubScreenState._statusChip(l.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => BusinessDetailScreen(listingId: l.id)),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
          ],
        );
      },
    );
  }
}
