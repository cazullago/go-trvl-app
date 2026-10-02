import '../config/affiliate_config.dart';
import '../models/models.dart';
import '../models/monetization_models.dart';
import 'app_config_service.dart';

/// Builds outbound affiliate links for places and destinations.
///
/// Links are external deep links only. No money ever flows through the app,
/// and no person-to-person transfers exist here. When affiliates are disabled
/// or no real affiliate ID has been pasted into the config, this service
/// returns empty lists so all affiliate UI stays hidden.
class AffiliateService {
  static const List<String> buttonLabels = [
    'View Deal',
    'Book with Partner',
    'Check Availability',
  ];

  /// True when affiliates are enabled (build-time config OR the remote
  /// admin flag) AND every partner template has a real affiliate ID pasted
  /// (no leftover 'YOUR_' placeholder tokens).
  bool get _ready =>
      (AffiliateConfig.affiliatesEnabled ||
          AppConfigService().affiliatesEnabled) &&
      AffiliateConfig.partners.every((p) => !p.urlTemplate.contains('YOUR_'));

  String _buildUrl(AffiliatePartner partner, String tokenValue) =>
      partner.urlTemplate
          .replaceAll('{place}', Uri.encodeComponent(tokenValue))
          .replaceAll('{destination}', Uri.encodeComponent(tokenValue));

  List<AffiliateLink> _linksFor(
      List<AffiliatePartner> partners, String tokenValue) {
    if (!_ready || partners.isEmpty) return [];
    final links = <AffiliateLink>[];
    for (final partner in partners) {
      final url = _buildUrl(partner, tokenValue);
      for (final label in buttonLabels.take(3)) {
        links.add(AffiliateLink(
          label: label,
          url: url,
          partnerName: partner.name,
        ));
      }
    }
    return links;
  }

  List<AffiliateLink> linksForPlace(Place place) => _linksFor(
        AffiliateConfig.partners
            .where((p) => p.appliesToCategories.contains(place.category))
            .toList(),
        place.name,
      );

  List<AffiliateLink> linksForDestination(Destination d) => _linksFor(
        AffiliateConfig.partners
            .where((p) =>
                p.appliesToCategories.contains('where_to_stay') ||
                p.urlTemplate.contains('{destination}'))
            .toList(),
        d.name,
      );
}
