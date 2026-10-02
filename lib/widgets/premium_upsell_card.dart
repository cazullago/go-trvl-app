import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../theme/boho_theme.dart';
import 'store_price_text.dart';

/// Tasteful Premium upsell used on the Matching tab and the Profile tab.
///
/// The price shown comes from the store's product configuration via
/// [StorePriceText]; until the product is configured no amount is shown.
/// Tapping the button runs the real Play/App Store purchase through
/// [BillingService]; on success the user doc is flagged `premiumTraveler`
/// with a 30-day expiry and the auth state is refreshed so the rest of the
/// app picks it up immediately.
class PremiumUpsellCard extends StatelessWidget {
  /// When true, renders a slim one-line banner instead of the full card.
  final bool dense;

  /// Optional close affordance (used on the Matching tab banner).
  final VoidCallback? onClose;

  const PremiumUpsellCard({super.key, this.dense = false, this.onClose});

  /// Runs the premium purchase flow. Shows a snackbar with the outcome.
  /// Safe to call from any screen: no-ops when nobody is signed in.
  static Future<void> buy(BuildContext context) async {
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid ?? '';
    if (uid.isEmpty) return;
    final ok = await BillingService().buyTravelerPremium();
    if (!context.mounted) return;
    if (ok) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'premiumTraveler': true,
          'premiumExpiry':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        });
        await auth.refreshUser();
      } catch (_) {
        // The purchase succeeded; a doc-write failure must not pretend
        // otherwise. The flag can be repaired from the receipt later.
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome to Premium! Your whole map is now unlocked.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.forest,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No worries, Premium will be here when you want it.',
              style: BohoFonts.body(14, color: Colors.white)),
          backgroundColor: BohoColors.cocoaSoft,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (dense) return _dense(context);
    return _full(context);
  }

  Widget _shell(BuildContext context, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BohoColors.coralDeep, BohoColors.terracotta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BohoColors.coralDeep.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _dense(BuildContext context) {
    return _shell(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: StorePriceText(
                  productId: BillingService.kPremiumTraveler,
                  label: 'Go Premium',
                  trailing: ': whole map, see who viewed and liked you',
                  style: BohoFonts.body(12.5,
                      color: Colors.white, weight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => buy(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BohoColors.coralDeep,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Go Premium',
                  style: BohoFonts.body(12.5, weight: FontWeight.w800)),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child:
                      Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _full(BuildContext context) {
    return _shell(
      context,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                  child: Text('⭐', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go Premium',
                      style: BohoFonts.heading(18, color: Colors.white)),
                  const SizedBox(height: 4),
                  StorePriceText(
                      productId: BillingService.kPremiumTraveler,
                      label: 'Go Premium',
                      trailing:
                          ': whole map unlocked, plus see who viewed and liked you.',
                      style: BohoFonts.body(13, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BohoColors.coralDeep,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => buy(context),
              child: StorePriceText(
                  productId: BillingService.kPremiumTraveler,
                  label: 'Go Premium',
                  style: BohoFonts.body(13, weight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
