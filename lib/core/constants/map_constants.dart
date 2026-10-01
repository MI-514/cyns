/// Map configuration constants for CYN (Chase Your Needs).
///
/// Uses high-speed CartoDB Voyager tiles (clean road graphics, no 403 block)
/// and OpenStreetMap fallback, plus OSRM live routing.
class MapConstants {
  // Default center (Lahore, Pakistan)
  static const double defaultLat = 31.5204;
  static const double defaultLng = 74.3587;

  // Zoom levels
  static const double defaultZoom = 14.0;
  static const double trackingZoom = 16.0;
  static const double pickerZoom = 16.0;
  static const double minZoom = 4.0;
  static const double maxZoom = 19.0;

  // Live location update settings
  static const int distanceFilterMeters = 8;

  // Route recalculation threshold (meters)
  static const double routeRecalcThresholdMeters = 80;

  // OSRM free public routing API
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  /// Carto.com API Key (paste your CARTO key here if you have one, or leave empty for free OpenStreetMap)
  static const String cartoApiKey = "cb1_45zn_1_780e44e0cf6d33aa5c34adb6";

  // OpenStreetMap tile server (Free, open-source, no API key required)
  static const String osmTileUrl =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const List<String> osmTileSubdomains = ['a', 'b', 'c'];

  /// Primary modern raster tiles:
  /// If a valid Carto API key is provided, uses CartoDB Voyager.
  /// Otherwise, seamlessly uses OpenStreetMap tiles (eliminating "API key required carto.com" watermark).
  static String get primaryTileUrl {
    if (cartoApiKey.trim().isNotEmpty && cartoApiKey != "YOUR_KEY") {
      return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$cartoApiKey';
    }
    return osmTileUrl;
  }

  /// CartoDB Voyager Vector Style (for MapLibre/vector engines if needed)
  /// Format: https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json?key=YOUR_KEY
  static String get vectorStyleUrl {
    if (cartoApiKey.trim().isNotEmpty && cartoApiKey != "YOUR_KEY") {
      return 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json?key=$cartoApiKey';
    }
    return 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
  }

  static List<String> get primaryTileSubdomains {
    if (cartoApiKey.trim().isNotEmpty && cartoApiKey != "YOUR_KEY") {
      return const ['a', 'b', 'c', 'd'];
    }
    return osmTileSubdomains;
  }

  // Legitimate App package identifier
  static const String packageName = 'cyn.chaseyourneeds.pk';
}
