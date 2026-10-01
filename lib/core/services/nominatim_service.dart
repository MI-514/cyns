import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/map_constants.dart';

/// A single place result returned by Nominatim search or reverse geocoding.
class NominatimPlace {
  final double lat;
  final double lng;
  final String displayName;
  final String? road;
  final String? suburb;
  final String? city;
  final String? state;
  final String? country;
  final String type;

  NominatimPlace({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.road,
    this.suburb,
    this.city,
    this.state,
    this.country,
    this.type = '',
  });

  /// Build a short, readable address (e.g. "Johar Town, Lahore, Pakistan")
  String get shortAddress {
    final parts = <String>[];
    if (road != null && road!.isNotEmpty) parts.add(road!);
    if (suburb != null && suburb!.isNotEmpty) parts.add(suburb!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);

    if (parts.isEmpty) return displayName;
    return parts.join(', ');
  }

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    return NominatimPlace(
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
      displayName: json['display_name'] ?? '',
      road: address['road'] ?? address['pedestrian'] ?? address['footway'],
      suburb: address['suburb'] ??
          address['neighbourhood'] ??
          address['hamlet'] ??
          address['village'],
      city: address['city'] ??
          address['town'] ??
          address['municipality'] ??
          address['county'],
      state: address['state'],
      country: address['country'],
      type: json['type'] ?? '',
    );
  }
}

/// 100% free geocoding service using OpenStreetMap Nominatim.
///
/// - No API key required
/// - No billing or charges
/// - Works on every device (Android, iOS, Huawei, etc.)
/// - Rate limit: max 1 request per second (Nominatim usage policy)
///
/// Features:
/// - **Forward Geocoding**: Search text → coordinates + address
/// - **Reverse Geocoding**: Coordinates → readable address
/// - **Autocomplete Search**: Live search suggestions as user types
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Tracks last request time to enforce 1 req/sec rate limit
  static DateTime _lastRequestTime = DateTime(2000);

  /// Enforce Nominatim rate limit (1 request per second)
  static Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime);
    if (elapsed.inMilliseconds < 1100) {
      await Future.delayed(
          Duration(milliseconds: 1100 - elapsed.inMilliseconds));
    }
    _lastRequestTime = DateTime.now();
  }

  /// Common headers required by Nominatim usage policy
  static Map<String, String> get _headers => {
        'User-Agent': '${MapConstants.packageName}/1.0',
        'Accept': 'application/json',
      };

  // ───────────────────────────────────────────────────────
  // Forward Geocoding: Search text → list of places
  // ───────────────────────────────────────────────────────

  /// Search for places matching [query].
  ///
  /// Returns up to [limit] results. Set [countryCode] to restrict results
  /// to a specific country (e.g. 'pk' for Pakistan).
  ///
  /// Used for: location picker search bar, autocomplete suggestions.
  static Future<List<NominatimPlace>> searchPlaces({
    required String query,
    int limit = 5,
    String? countryCode,
  }) async {
    if (query.trim().length < 2) return [];

    await _enforceRateLimit();

    try {
      final params = {
        'q': query.trim(),
        'format': 'json',
        'addressdetails': '1',
        'limit': limit.toString(),
        'accept-language': 'en',
      };
      if (countryCode != null) {
        params['countrycodes'] = countryCode;
      }

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: params);
      final response =
          await http.get(uri, headers: _headers).timeout(
                const Duration(seconds: 8),
              );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => NominatimPlace.fromJson(e)).toList();
      }
    } catch (_) {
      // Network error, timeout, or parsing failure — return empty
    }

    return [];
  }

  // ───────────────────────────────────────────────────────
  // Reverse Geocoding: Coordinates → readable address
  // ───────────────────────────────────────────────────────

  /// Get a human-readable address from GPS [lat]/[lng] coordinates.
  ///
  /// Returns a [NominatimPlace] with full address details, or null on failure.
  ///
  /// Used for: showing address when user moves map pin, current location address.
  static Future<NominatimPlace?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    await _enforceRateLimit();

    try {
      final uri =
          Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': 'en',
        'zoom': '18',
      });

      final response =
          await http.get(uri, headers: _headers).timeout(
                const Duration(seconds: 8),
              );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['lat'] != null) {
          return NominatimPlace.fromJson(data);
        }
      }
    } catch (_) {
      // Network error or timeout
    }

    return null;
  }

  // ───────────────────────────────────────────────────────
  // Convenience: Get formatted address string from coordinates
  // ───────────────────────────────────────────────────────

  /// Returns a short formatted address string from coordinates.
  /// Falls back to "Lat: xx, Lng: xx" if geocoding fails.
  ///
  /// Direct replacement for the old geocoding package's placemarkFromCoordinates.
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    final place = await reverseGeocode(lat: lat, lng: lng);
    if (place != null) {
      return place.shortAddress;
    }
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }
}
