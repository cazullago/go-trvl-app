import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monetization_models.dart';
import '../models/models.dart';

/// Premium membership status for GoTRVL PH.
///
/// Reads the `premiumTraveler` / `premiumExpiry` fields that [BillingService]
/// writes to users/<uid> on a successful store purchase (or test-mode
/// confirm). Nothing is gated on premium until the premium feature set
/// launches; this service performs no purchases itself.
class PremiumService {
  static const List<PremiumFeature> allFeatures = PremiumFeature.values;

  // Lazily resolved so this never crashes when Firebase is not configured.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// True when the user holds an active (unexpired) traveler premium.
  /// Never throws; returns false on any read error.
  Future<bool> isPremium(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final user = AppUser.fromMap(uid, doc.data() ?? const {});
      return user.isPremiumActive;
    } catch (_) {
      return false;
    }
  }
}
