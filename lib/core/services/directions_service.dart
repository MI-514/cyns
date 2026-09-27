import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants/map_constants.dart';

/// Holds the result of a route calculation.
class RouteInfo {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;

  RouteInfo({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Routing service using OSRM (Open Source Routing Machine).
///
/// Completely free — no API key, no billing, no usage limits for moderate traffic.
/// Uses the public demo server at router.project-osrm.org.
/// For production at scale, consider hosting your own OSRM instance.
class DirectionsService {
  /// Get a real road-following route between two GPS coordinates.
  ///
  /// Returns [RouteInfo] with polyline points, distance in km, and duration in minutes.
  /// Returns null if the route cannot be calculated (no internet, no road path, etc.).
  static Future<RouteInfo?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      // OSRM expects coordinates in longitude,latitude order
      final url = Uri.parse(
        '${MapConstants.osrmBaseUrl}/route/v1/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson&steps=false',
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();

          // OSRM returns [longitude, latitude] — swap to LatLng(lat, lng)
          List<LatLng> points = coordinates.map<LatLng>((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          return RouteInfo(
            polylinePoints: points,
            distanceKm: distanceMeters / 1000.0,
            durationMinutes: (durationSeconds / 60.0).ceil(),
          );
        }
      }
    } catch (_) {
      // Network error, timeout, or parsing failure
    }

    return null;
  }

  /// Format distance for display (e.g., "450 m" or "2.3 km").
  static String formatDistance(double distanceKm) {
    if (distanceKm <= 0.0) return 'Nearby';
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Format duration for display (e.g., "5 min" or "1h 20m").
  static String formatDuration(int minutes) {
    if (minutes <= 0) return 'Arrived';
    if (minutes < 2) return '1-2 min';
    if (minutes < 60) return '$minutes min';
    int h = minutes ~/ 60;
    int m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
