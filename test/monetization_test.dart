import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/monetization_models.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/config/affiliate_config.dart';
import 'package:go_trvl/services/affiliate_service.dart';
import 'package:go_trvl/services/premium_service.dart';

Place _samplePlace() => Place(
      id: 'test-place',
      name: 'Test Resort',
      category: 'where_to_stay',
      placeType: 'resort',
      description: 'A lovely test resort.',
      priceRange: '\u20b15000',
      area: 'Test Area',
      bestTime: 'Dry season',
      lat: 10.0,
      lng: 123.0,
    );

void main() {
  group('Monetization policy guards', () {
    test('Affiliate links are always disclosed as sponsored', () {
      const link = AffiliateLink(
        label: 'View Deal',
        url: 'https://example.com',
        partnerName: 'Example',
      );
      expect(link.isSponsored, isTrue,
          reason: 'Every affiliate link must carry the disclosure flag');
    });

    test('Affiliate buttons hide when the program is disabled', () {
      expect(AffiliateConfig.affiliatesEnabled, isFalse);
      final links = AffiliateService().linksForPlace(_samplePlace());
      expect(links, isEmpty,
          reason: 'No dead affiliate buttons may ever be shown');
    });

    test('Affiliate button labels are the three approved labels', () {
      expect(AffiliateService.buttonLabels,
          ['View Deal', 'Book with Partner', 'Check Availability']);
    });
  });

  group('Business tiers', () {
    test('Free tier has a non-empty feature list', () {
      expect(BusinessTier.freeFeatures, isNotEmpty);
    });

    test('Premium tier offers strictly more than free', () {
      expect(BusinessTier.premiumFeatures, isNotEmpty);
      expect(BusinessTier.premiumFeatures.length,
          greaterThan(BusinessTier.freeFeatures.length));
      expect(BusinessTier.premium.label, 'Premium');
      expect(BusinessTier.free.label, 'Free');
    });

    test('BusinessListing serializes tier and status as strings', () {
      final listing = BusinessListing(
        id: 'b1',
        ownerUid: 'u1',
        name: 'Test Cafe',
        category: 'cafe',
        description: 'Cozy.',
        phone: '',
        website: '',
        provinceId: 'cebu',
        tier: BusinessTier.free,
        status: 'pending',
        createdAt: DateTime(2026, 1, 1),
      );
      final map = listing.toMap();
      expect(map['tier'], 'free');
      expect(map['status'], 'pending');
      expect(BusinessListing.fromMap('b1', map).name, 'Test Cafe');
    });
  });

  group('Premium membership (future)', () {
    test('Premium feature list matches the six required features', () {
      expect(
        PremiumFeature.values.toSet(),
        {
          PremiumFeature.advancedPlanner,
          PremiumFeature.offlineGuides,
          PremiumFeature.exclusiveDeals,
          PremiumFeature.unlimitedTrips,
          PremiumFeature.advancedMemories,
          PremiumFeature.premiumItineraries,
        },
      );
      expect(PremiumService.allFeatures.length, 6);
      for (final f in PremiumFeature.values) {
        expect(f.label, isNotEmpty);
        expect(f.description, isNotEmpty);
      }
    });

    test('Nobody is premium today and nothing is gated', () async {
      expect(await PremiumService().isPremium('any-uid'), isFalse);
    });
  });

  group('Live gifts (model only)', () {
    test('Virtual gift samples exist with positive coin prices', () {
      expect(VirtualGift.samples, isNotEmpty);
      for (final g in VirtualGift.samples) {
        expect(g.coinPrice, greaterThan(0));
        expect(g.name, isNotEmpty);
      }
    });
  });

  group('Ads', () {
    test('Ad slot constants are defined', () {
      expect(AdPlacement.slotFeed, 'feed_inline');
      expect(AdPlacement.slotMarketplace, 'marketplace_banner');
      expect(AdPlacement.slotExplore, 'explore_banner');
    });
  });
}
