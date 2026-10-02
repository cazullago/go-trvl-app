import 'package:flutter/material.dart';

import '../theme/boho_theme.dart';

/// In-app Privacy Policy and Terms of Service (concise).
///
/// Contact placeholder follows the existing convention:
/// [YOUR SUPPORT EMAIL], replaced with the real address before release.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _supportEmail = '[YOUR SUPPORT EMAIL]';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Legal',
            style: BohoFonts.heading(22, color: BohoColors.espresso)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _docCard(
            title: 'Privacy Policy',
            updated: 'Effective 2026-09-30',
            sections: const [
              (
                'Consent under the PH Data Privacy Act',
                'By creating an account you consent, under Republic Act No. 10173 (Data Privacy Act of 2012), to our collection and processing of your personal data as described here. You may withdraw consent any time by deleting your account in Settings.'
              ),
              (
                'What we collect',
                'Account data you give us: name, email, age, gender, location, bio, and profile or cover photos. Activity data: places you mark done, posts, memories, quest progress, matches, likes, and messages. Device data: approximate location only when you use nearby features, and standard diagnostics.'
              ),
              (
                'Why we use it',
                'To run the app: your traveler profile, matching with travel buddies, the map and gamification, safety (report and block), and support. We never sell your personal data.'
              ),
              (
                'Your rights',
                'You have the right to access, correct, and delete your data, and to a copy of it. Edit most fields in Settings, or delete your account there to erase your profile, posts, and photos. For other requests, email $_supportEmail.'
              ),
              (
                'Sharing and retention',
                'Your public profile, posts, and public memories are visible to other travelers. We share data only with our infrastructure providers (Firebase) and when required by law. We keep your data while your account is active and delete it when you delete your account.'
              ),
            ],
          ),
          const SizedBox(height: 16),
          _docCard(
            title: 'Terms of Service',
            updated: 'Effective 2026-09-30',
            sections: const [
              (
                '18+ for Travel Buddy',
                'Finding and messaging travel buddies is strictly for travelers aged 18 and above. Accounts that misrepresent their age may be suspended.'
              ),
              (
                'No money custody',
                'GoTRVL never holds your money. Travel bookings are completed with external providers, and digital purchases are billed by Google Play or the App Store. We never operate wallets or peer-to-peer transfers.'
              ),
              (
                'Content rules',
                'Be kind. No harassment, hate speech, spam, scams, sexual content involving minors, or fake profiles. Posts, comments, and messages pass an automatic community check, and every profile can be reported or blocked. Violations may lead to suspension.'
              ),
              (
                'Your content',
                'You keep ownership of what you post. By posting, you give us a license to display it in the app. Do not post anything you do not have the right to share.'
              ),
              (
                'Accounts and termination',
                'You are responsible for activity on your account. We may suspend accounts that break these terms or the law. You may delete your account any time in Settings; deletion is permanent.'
              ),
              (
                'Contact',
                'Questions about these terms or your data: $_supportEmail.'
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docCard(
      {required String title,
      required String updated,
      required List<(String, String)> sections}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: BohoFonts.script(30, color: BohoColors.espresso)),
          const SizedBox(height: 2),
          Text(updated,
              style: BohoFonts.body(12,
                  color: BohoColors.espresso.withValues(alpha: 0.55))),
          const SizedBox(height: 14),
          for (final (heading, body) in sections) ...[
            Text(heading,
                style: BohoFonts.body(15,
                    color: BohoColors.espresso,
                    weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(body,
                style: BohoFonts.body(13.5,
                    color:
                        BohoColors.espresso.withValues(alpha: 0.8))),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
