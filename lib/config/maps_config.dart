/// Google Maps configuration for GoTRVL PH.
///
/// The user adds their own Google Maps API keys (Android + iOS) plus billing
/// in the Google Cloud Console, then flips [hasApiKey] to true. The map
/// screen reads [hasApiKey] to choose the real map vs the static fallback.
class MapsConfig {
  static const bool hasApiKey = false;
  static const String androidApiKey = '';
  static const String iosApiKey = '';
}
