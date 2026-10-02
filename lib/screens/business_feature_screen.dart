import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';

/// Explains paid featured visibility for businesses.
/// NO checkout UI: featuring is arranged manually until online payments
/// land, so this screen only describes the perks and offers a contact CTA.
class BusinessFeatureScreen extends StatelessWidget {
  const BusinessFeatureScreen({super.key});

  /// Placeholder contact: deliberately NOT a real address.
  static const _contactEmail = '[YOUR BUSINESS EMAIL]';

  Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const {
        'subject': 'Go TRVL featured business inquiry',
      },
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not open your mail app. Email us at $_contactEmail.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Feature Your Business',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Get featured',
              style: BohoFonts.script(34, color: BohoColors.espresso)),
          const SizedBox(height: 8),
          Text(
            'Stand out to travelers planning their next island hop. '
            'Featured businesses get premium placement across the app.',
            style: BohoFonts.body(15, color: BohoColors.espresso),
          ),
          const SizedBox(height: 20),
          _perkCard([
            _perk(Icons.push_pin_rounded, 'Featured placement',
                'Appear at the top of search results and category lists.'),
            _perk(Icons.photo_library_rounded, 'More photos',
                'Showcase your place with a full photo gallery.'),
            _perk(Icons.local_offer_rounded, 'Promotions',
                'Publish special offers travelers can see right away.'),
            _perk(Icons.analytics_rounded, 'Analytics',
                'See how many travelers view and tap your listing.'),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BohoColors.sun.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BohoColors.tan, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_rounded, color: BohoColors.forest),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Clearly labeled as Featured/Sponsored, so travelers '
                    'always know it is a paid placement.',
                    style: BohoFonts.body(14, color: BohoColors.espresso),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Contact us to get featured',
              icon: Icons.mail_rounded,
              onPressed: () => _contact(context),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Online payments coming soon: featuring is currently '
              'arranged manually.',
              style: BohoFonts.body(13,
                  color: BohoColors.espresso.withValues(alpha: 0.65)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _perkCard(List<Widget> perks) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(children: perks),
    );
  }

  Widget _perk(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: BohoColors.terracotta.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: BohoColors.terracotta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: BohoFonts.body(15,
                        color: BohoColors.espresso, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: BohoFonts.body(14, color: BohoColors.espresso)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
