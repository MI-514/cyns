/// Map configuration constants for Chase Your Need.
///
/// Uses OpenStreetMap tiles (free, no API key) and OSRM routing (free, no API key).
class MapConstants {
  // Default center (Lahore, Pakistan)
  static const double defaultLat = 31.5204;
  static const double defaultLng = 74.3587;

  // Zoom levels
  static const double defaultZoom = 14.0;
  static const double trackingZoom = 15.5;
  static const double pickerZoom = 16.0;
  static const double minZoom = 4.0;
  static const double maxZoom = 18.0;

  // Live location update settings
  static const int distanceFilterMeters = 10;

  // Route recalculation threshold (meters) — recalculates route when
  // the worker has moved this far from the point where the route was last calculated
  static const double routeRecalcThresholdMeters = 100;

  // OSRM free public routing API (no API key required)
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  // OpenStreetMap tile server (free, no API key required)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // App package name for OSM user-agent policy
  static const String packageName = 'com.example.cyns';
}
