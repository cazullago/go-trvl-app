import '../models/monetization_models.dart';

/// Affiliate program configuration for GoTRVL PH.
///
/// =====================================================================
/// TO ENABLE AFFILIATES:
///   1. PASTE YOUR REAL AFFILIATE ID WHERE IT SAYS YOUR_AFFILIATE_ID below.
///   2. Set affiliatesEnabled = true.
/// Until both are done, ALL affiliate UI stays hidden across the app.
/// =====================================================================
class AffiliateConfig {
  static const bool affiliatesEnabled = false;

  static const List<AffiliatePartner> partners = [
    AffiliatePartner(
      id: 'stays',
      name: 'Example Stays',
      // PASTE YOUR REAL AFFILIATE ID WHERE IT SAYS YOUR_AFFILIATE_ID
      urlTemplate:
          'https://www.example-stays.com/search?aff_id=YOUR_AFFILIATE_ID&dest={destination}',
      appliesToCategories: ['where_to_stay'],
    ),
    AffiliatePartner(
      id: 'experiences',
      name: 'Example Experiences',
      // PASTE YOUR REAL AFFILIATE ID WHERE IT SAYS YOUR_AFFILIATE_ID
      urlTemplate:
          'https://www.example-experiences.com/activities?aff_id=YOUR_AFFILIATE_ID&place={place}',
      appliesToCategories: ['things_to_do', 'where_to_go'],
    ),
  ];
}
