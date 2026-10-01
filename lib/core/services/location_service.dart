import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/map_constants.dart';
import 'nominatim_service.dart';

class LocationService {
  /// Default fallback position when GPS is off/unavailable (Lahore, Pakistan)
  static Position get defaultPosition => Position(
        latitude: MapConstants.defaultLat,
        longitude: MapConstants.defaultLng,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

  /// Request permission and get current Position with multi-tiered fallback
  static Future<Position> getCurrentLocation() async {
    // 1. Immediately return last known cached position if available
    Position? lastPos;
    try {
      lastPos = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return lastPos ?? defaultPosition;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return lastPos ?? defaultPosition;
      }

      // 2. Try High Accuracy (GPS hardware chip) with 6s timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
        return pos;
      } catch (_) {
        // 3. Fallback to Medium Accuracy (Cell towers & Wi-Fi — works indoors & fast)
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );
          return pos;
        } catch (_) {}
      }
    } catch (_) {}

    return lastPos ?? defaultPosition;
  }

  /// Prompt user to enable GPS Service in System Settings
  static void promptEnableGps(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off,
            size: 48, color: AppColors.statusPending),
        title: const Text('GPS Location is OFF'),
        content: const Text(
          'Your device GPS location service is currently turned off.\n\nPlease turn on Location/GPS to find nearby skilled workers accurately.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Turn On GPS'),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
          ),
        ],
      ),
    );
  }

  /// Prompt user to grant location permission in App Settings
  static void promptOpenAppSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.security,
            size: 48, color: AppColors.statusRejected),
        title: const Text('Location Permission Needed'),
        content: const Text(
          'Location permission was denied. Please grant location access in App Settings to search nearby service providers.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Open App Settings'),
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  /// Get readable address from coordinates using Nominatim (OpenStreetMap — free)
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    return NominatimService.getAddressFromCoordinates(lat, lng);
  }

  /// Calculate exact real-world distance in Kilometers using Geolocator's geodesic WGS84 formula
  static double calculateDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    if (startLat == 0.0 || startLng == 0.0 || endLat == 0.0 || endLng == 0.0) {
      return 0.0;
    }
    double meters =
        Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return meters / 1000.0;
  }

  /// Format distance into readable text (e.g. "450 m away" or "2.4 km away")
  static String formatDistance(double distanceKm) {
    if (distanceKm <= 0.0) return "Nearby Location";
    if (distanceKm < 1.0) {
      int meters = (distanceKm * 1000).round();
      return "$meters m away";
    }
    return "${distanceKm.toStringAsFixed(1)} km away";
  }

  /// Calculate Estimated Arrival Time (assuming avg speed 30 km/h in urban area)
  static String calculateETA(double distanceKm) {
    if (distanceKm <= 0) return "Arrived";
    double hours = distanceKm / 30.0;
    int totalMinutes = (hours * 60).round();
    if (totalMinutes < 2) return "1-2 mins";
    if (totalMinutes < 60) return "$totalMinutes mins";
    int h = totalMinutes ~/ 60;
    int m = totalMinutes % 60;
    return "${h}h ${m}m";
  }

  /// Launch Turn-by-Turn GPS Navigation using any installed map app
  /// (Google Maps, OsmAnd, Waze, HERE, etc.) via standard geo: URI — no API key needed.
  static Future<void> openTurnByTurnNavigation(
      double destinationLat, double destinationLng) async {
    // Standard geo: URI — opens in whatever map app the user has installed
    final Uri geoUri = Uri.parse(
        'geo:$destinationLat,$destinationLng?q=$destinationLat,$destinationLng');

    // Fallback: open in OpenStreetMap web (completely free, no API key)
    final Uri fallbackUri = Uri.parse(
        'https://www.openstreetmap.org/directions?engine=osrm_car&route=;$destinationLat,$destinationLng');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Calculate bearing angle in degrees between two coordinates for map marker heading rotation
  static double calculateBearing(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Listen to continuous live location stream for active worker navigation
  static Stream<Position> getLocationStream({
    int distanceFilterMeters = 5,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }
}
