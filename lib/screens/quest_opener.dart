import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/game_service.dart';
import '../services/permission_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/store_price_text.dart';
import 'place_detail_sheet.dart';

/// Shared quest-open flow for places opened outside the map screen
/// (province Explore pages, city lists): unlock gate first, then the
/// standard place detail sheet. Works with authored quests and with
/// synthetic [QuestPlace]s (cities, provinces) since every check keys on
/// the place-id string.
class QuestOpener {
  /// Opens [q]: returns after the detail sheet closes. Refreshes the
  /// signed-in user afterwards so points/memories stay current.
  static Future<void> open(
    BuildContext context,
    QuestPlace q, {
    required List<QuestPlace> allPlaces,
  }) async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    if (user == null) {
      _snack(context, 'Sign in to open quest details. 🌴');
      return;
    }
    var unlocked = await _isUnlocked(user, q, allPlaces, null, null);
    Position? pos;
    if (!unlocked) {
      // One location attempt: being within 3 km unlocks for free.
      final ok = await PermissionService()
          .ensureLocation(context, 'to unlock nearby places');
      if (ok) {
        try {
          pos = await Geolocator.getCurrentPosition(
                  locationSettings:
                      const LocationSettings(accuracy: LocationAccuracy.high))
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      if (pos != null) {
        unlocked =
            await _isUnlocked(user, q, allPlaces, pos.latitude, pos.longitude);
      }
    }
    if (!context.mounted) return;
    if (!unlocked) {
      _showUnlockSheet(context, q, allPlaces: allPlaces);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceDetailSheet(place: q, user: user),
    );
    if (context.mounted) await context.read<AuthService>().refreshUser();
  }

  static Future<bool> _isUnlocked(AppUser user, QuestPlace q,
      List<QuestPlace> allPlaces, double? lat, double? lng) async {
    try {
      return await GameService().isPlaceUnlocked(
        user: user,
        placeId: q.id,
        userLat: lat,
        userLng: lng,
        allPlaces: allPlaces,
      );
    } catch (_) {
      return false;
    }
  }

  static void _showUnlockSheet(BuildContext context, QuestPlace q,
      {required List<QuestPlace> allPlaces}) {
    final uid = context.read<AuthService>().user?.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 12),
            Text('🔒 ${q.name}', style: BohoFonts.heading(20)),
            const SizedBox(height: 6),
            Text(
              'Unlock to open details, earn ${q.points} pts, and post memories.',
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 14),
            _option(
              sheetCtx,
              Icons.task_alt_rounded,
              Text('Complete a task',
                  style: BohoFonts.body(15, weight: FontWeight.w800)),
              'Finish a quick travel task to unlock it now (+20 pts).',
              () async {
                if (uid == null) return;
                Navigator.of(sheetCtx).pop();
                await GameService().unlockViaTask(uid, q.id);
                if (!context.mounted) return;
                _snack(context, 'Unlocked! +20 pts. 🎉');
                await open(context, q, allPlaces: allPlaces);
              },
            ),
            _option(
              sheetCtx,
              Icons.lock_open_rounded,
              StorePriceText(
                productId: BillingService.kPlaceUnlock,
                label: 'Unlock now',
                style: BohoFonts.body(15, weight: FontWeight.w800),
              ),
              'One-time unlock, yours forever.',
              () async {
                if (uid == null) {
                  _snack(context, 'Sign in first. 🌴');
                  return;
                }
                final ok = await BillingService().buyPlaceUnlock(q.id);
                if (!context.mounted) return;
                if (ok) {
                  await GameService().unlockPlace(uid, q.id);
                  Navigator.of(sheetCtx).pop();
                  _snack(context, 'Unlocked — enjoy ${q.name}! 🔓');
                  await open(context, q, allPlaces: allPlaces);
                } else {
                  _snack(context,
                      'Purchase did not complete. No charge was made.');
                }
              },
            ),
            _option(
              sheetCtx,
              Icons.star_rounded,
              StorePriceText(
                productId: BillingService.kPremiumTraveler,
                label: 'Go Premium',
                style: BohoFonts.body(15, weight: FontWeight.w800),
              ),
              'Unlock every quest stop plus premium traveler perks.',
              () async {
                final ok = await BillingService().buyTravelerPremium();
                if (!context.mounted) return;
                Navigator.of(sheetCtx).pop();
                if (ok) {
                  await context.read<AuthService>().refreshUser();
                  _snack(context, 'Welcome to Premium! ⭐');
                  await open(context, q, allPlaces: allPlaces);
                } else {
                  _snack(context,
                      'Premium purchase did not complete. No charge was made.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _option(BuildContext ctx, IconData icon, Widget title,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BohoDecor.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BohoColors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: BohoColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  Text(subtitle,
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso.withValues(alpha: 0.65))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BohoColors.espresso),
          ],
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: BohoFonts.body(14, color: Colors.white)),
      backgroundColor: BohoColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }
}
