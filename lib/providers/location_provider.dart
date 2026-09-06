import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  String _currentAddress = 'Detecting location...';
  bool _isLoading = false;
  bool _isGpsDisabled = false;
  bool _isPermissionDenied = false;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get isGpsDisabled => _isGpsDisabled;
  bool get isPermissionDenied => _isPermissionDenied;

  Future<void> fetchCurrentLocation({BuildContext? context}) async {
    _isLoading = true;
    notifyListeners();

    // Check if GPS Service is Enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _currentPosition = null; // Clear any stale position!
      _currentAddress = 'GPS Location is turned OFF';
      _isGpsDisabled = true;
      _isLoading = false;
      notifyListeners();

      if (context != null && context.mounted) {
        LocationService.promptEnableGps(context);
      }
      return;
    }

    _isGpsDisabled = false;

    // Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _currentPosition = null; // Clear any stale position!
      _currentAddress = 'Location Permission Denied';
      _isPermissionDenied = true;
      _isLoading = false;
      notifyListeners();

      if (permission == LocationPermission.deniedForever &&
          context != null &&
          context.mounted) {
        LocationService.promptOpenAppSettings(context);
      }
      return;
    }

    _isPermissionDenied = false;

    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _currentPosition = pos;
      _currentAddress = await LocationService.getAddressFromCoordinates(
          pos.latitude, pos.longitude);
    } catch (_) {
      _currentPosition = null;
      _currentAddress = 'Unable to fetch current GPS coordinates';
    }

    _isLoading = false;
    notifyListeners();
  }

  double calculateDistance(double endLat, double endLng) {
    if (_currentPosition == null) return 0.0;
    return LocationService.calculateDistanceKm(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      endLat,
      endLng,
    );
  }

  String calculateETA(double distanceKm) {
    return LocationService.calculateETA(distanceKm);
  }
}
