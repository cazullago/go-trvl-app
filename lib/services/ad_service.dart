import '../models/monetization_models.dart';
import 'app_config_service.dart';

/// Serves ad placements per slot. Today this returns only the house ad that
/// promotes GoTRVL PH advertising itself; no third-party ad SDK is bundled.
class AdService {
  static const String houseAdTitle = 'Advertise with Go TRVL PH';

  /// Placements for a slot (use [AdPlacement.slotFeed],
  /// [AdPlacement.slotMarketplace], or [AdPlacement.slotExplore]).
  List<AdPlacement> placementsForSlot(String slot) {
    // The owner can disable all ad slots remotely from Admin → Settings.
    if (!AppConfigService().adsEnabled) return [];
    // Real ad inventory plugs in here later (AdMob, direct-sold, etc.).
    // Until then, every slot shows the house ad.
    return [
      AdPlacement(
        id: 'house_$slot',
        slot: slot,
        title: houseAdTitle,
        imageUrl: '',
        ctaLabel: 'Learn more',
        targetUrl: '',
        isHouseAd: true,
      ),
    ];
  }
}
