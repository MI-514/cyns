import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';

class LocationService {
  /// Request permission and get current Position
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
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

  /// Get readable address from coordinates
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return "${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}";
      }
    } catch (_) {}
    return "Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}";
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

  /// Launch Native Turn-by-Turn GPS Navigation directly in Google Maps App
  static Future<void> openTurnByTurnNavigation(
      double destinationLat, double destinationLng) async {
    final Uri googleMapsUri =
        Uri.parse('google.navigation:q=$destinationLat,$destinationLng&mode=d');
    final Uri fallbackUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
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
