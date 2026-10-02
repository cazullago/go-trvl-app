import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Store billing for GoTRVL PH, wrapping the `in_app_purchase` plugin.
///
/// Real product ids are created in Play Console / App Store Connect and must
/// be pasted into the constants below before a store release. Nothing here
/// moves money person-to-person: purchases are store products sold by the
/// app only (see MONETIZATION_POLICY.md).
class BillingService {
  static final BillingService _i = BillingService._();
  factory BillingService() => _i;
  BillingService._();

  // TEST BUILD ONLY — set false for store release.
  static const bool debugBypass = true;

  /// Give this to MaterialApp (navigatorKey:) so test-mode dialogs can show
  /// without a per-call BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Product ids. Create each product in Play Console (Android) and App Store
  // Connect (iOS) with EXACTLY these ids before release; unconfigured ids
  // make every buy* call return false.
  static const String kPremiumTraveler = 'gotrvl_premium_traveler_monthly';
  static const String kPlaceUnlock = 'gotrvl_place_unlock';
  static const String kBusinessFeatured = 'gotrvl_business_featured';
  static const String kBusinessPremium = 'gotrvl_business_premium';

  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<bool> _premiumCtrl =
      StreamController<bool>.broadcast();

  /// Cache of store price lookups so upsell widgets do not re-query the
  /// store on every build. A null value means "not configured / unknown" —
  /// callers must show neutral copy, never a guessed amount.
  final Map<String, String?> _priceCache = {};

  /// The store's localized price for [productId] (e.g. "₱149"), or null
  /// when the product is not configured in the store yet. Never throws.
  Future<String?> priceOf(String productId) async {
    if (_priceCache.containsKey(productId)) return _priceCache[productId];
    try {
      final pd = await _product(productId);
      final price = (pd != null && pd.price.isNotEmpty) ? pd.price : null;
      _priceCache[productId] = price;
      return price;
    } catch (_) {
      _priceCache[productId] = null;
      return null;
    }
  }

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Traveler-premium state. In debug/test builds this is a manual
  /// controller (set on test-mode confirm or on real purchase events);
  /// screens subscribe and rebuild.
  Stream<bool> get premiumTraveler => _premiumCtrl.stream;

  // Lazily resolved so init() never crashes when Firebase is not set up yet.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get _debug => debugBypass;

  /// Subscribes to the store purchase stream. Never throws (main.dart
  /// already wraps this call in try/catch, and it is safe without a store).
  Future<void> init() async {
    try {
      _purchaseSub?.cancel();
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<bool> _storeAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Test-mode confirm dialog: "TEST MODE — no real charge". Returns the
  /// user's choice (null-safe: dismissing counts as Cancel).
  Future<bool> _testModeDialog(String productLabel) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint(
          '[Billing] TEST MODE $productLabel confirmed (no dialog context)');
      return true;
    }
    final choice = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('TEST MODE'),
        content: Text('No real charge will be made for "$productLabel".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return choice == true;
  }

  Future<ProductDetails?> _product(String id) async {
    try {
      final res = await _iap.queryProductDetails({id});
      if (res.notFoundIDs.contains(id)) return null;
      for (final p in res.productDetails) {
        if (p.id == id) return p;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Debug-bypass check shared by every buy* method: in a test build with
  /// no store, show the test-mode dialog instead of touching the store.
  /// Returns null when the real store flow should proceed, otherwise the
  /// test-mode choice.
  Future<bool?> _maybeDebugBypass(String productId, String label) async {
    if (!_debug) return null;
    if (await _storeAvailable()) return null;
    return _testModeDialog(label);
  }

  Future<bool> _buy(String productId, String label, bool consumable) async {
    try {
      final debugChoice = await _maybeDebugBypass(productId, label);
      if (debugChoice != null) return debugChoice;
      final pd = await _product(productId);
      if (pd == null) {
        debugPrint('[Billing] product not found in store: $productId');
        return false;
      }
      final param = PurchaseParam(productDetails: pd);
      if (consumable) {
        return await _iap.buyConsumable(
            purchaseParam: param, autoConsume: true);
      }
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// Monthly traveler premium (subscription in the stores). In test builds
  /// without a store this shows the test-mode dialog and applies the
  /// premium locally on confirm.
  Future<bool> buyTravelerPremium() async {
    final debugChoice =
        await _maybeDebugBypass(kPremiumTraveler, 'Traveler Premium (monthly)');
    if (debugChoice != null) {
      if (debugChoice) await _fulfillTravelerPremium();
      return debugChoice;
    }
    return _buy(kPremiumTraveler, 'Traveler Premium', false);
  }

  /// One quest-place unlock (consumable).
  Future<bool> buyPlaceUnlock(String placeId) =>
      _buy(kPlaceUnlock, 'Place unlock ($placeId)', true);

  /// Featured placement for one business listing (consumable).
  Future<bool> buyBusinessFeatured(String listingId) =>
      _buy(kBusinessFeatured, 'Featured listing ($listingId)', true);

  /// Business premium tier (non-consumable/subscription in the stores).
  Future<bool> buyBusinessPremium() =>
      _buy(kBusinessPremium, 'Business Premium', false);

  // ---- Purchase stream handling ----

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      _handlePurchase(p);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails p) async {
    try {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == kPremiumTraveler) {
          await _fulfillTravelerPremium();
        }
        await _iap.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        await _iap.completePurchase(p);
      }
    } catch (_) {}
  }

  /// Grants traveler premium: Firestore users/<uid> premiumTraveler=true
  /// with premiumExpiry = now + 30 days, and notifies the stream.
  Future<void> _fulfillTravelerPremium() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await _db.collection('users').doc(uid).update({
          'premiumTraveler': true,
          'premiumExpiry':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });
      }
    } catch (_) {}
    if (!_premiumCtrl.isClosed) _premiumCtrl.add(true);
  }

  /// Call from a test/debug UI to flip premium state manually.
  void setDebugPremium(bool value) {
    if (!_premiumCtrl.isClosed) _premiumCtrl.add(value);
  }
}
