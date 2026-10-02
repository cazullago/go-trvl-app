import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote feature flags from Firestore `app_config/global`.
///
/// The Admin Dashboard (Settings) can flip these without a new app build.
/// Local defaults keep the app working when Firebase is unconfigured, the
/// doc is missing, or the device is offline. Reads are public; only admins
/// can write (see firestore.rules).
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._();
  factory AppConfigService() => _instance;
  AppConfigService._();

  /// Master switch for affiliate buttons. Real affiliate IDs must still be
  /// pasted into affiliate_config.dart; this flag alone never fabricates
  /// links.
  bool affiliatesEnabled = false;

  /// Master switch for ad slots (house ad + future inventory).
  bool adsEnabled = true;

  /// Master switch for the LIVE surface (Home "Live Now" section).
  bool liveEnabled = true;

  /// Kept for the admin Settings screen; the premium screen is info-only.
  bool premiumComingSoon = true;

  /// Pull the latest flags. Call once at startup; safe to call again.
  Future<void> refresh() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .get();
      final d = doc.data();
      if (d == null) return;
      affiliatesEnabled = d['affiliatesEnabled'] == true;
      adsEnabled = d['adsEnabled'] != false;
      liveEnabled = d['liveEnabled'] != false;
      premiumComingSoon = d['premiumComingSoon'] != false;
    } catch (_) {
      // Offline or unconfigured: keep local defaults.
    }
  }
}
