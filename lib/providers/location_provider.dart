import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition = LocationService.defaultPosition;
  String _currentAddress = 'Lahore, Pakistan';
  bool _isLoading = false;
  bool _isGpsDisabled = false;
  bool _isPermissionDenied = false;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get isGpsDisabled => _isGpsDisabled;
  bool get isPermissionDenied => _isPermissionDenied;

  LocationProvider() {
    _initLocation();
  }

  void _initLocation() async {
    // 1. Immediately read last known position in background on app start
    try {
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _currentPosition = lastPos;
        notifyListeners();
        final addr = await LocationService.getAddressFromCoordinates(
            lastPos.latitude, lastPos.longitude);
        _currentAddress = addr;
        notifyListeners();
      }
    } catch (_) {}

    // 2. Fetch fresh live location
    await fetchCurrentLocation();
  }

  Future<void> fetchCurrentLocation({BuildContext? context}) async {
    _isLoading = true;
    notifyListeners();

    // 1. Quick check for instant cached position
    try {
      Position? cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        _currentPosition = cached;
        _isGpsDisabled = false;
        _isPermissionDenied = false;
        notifyListeners();
      }
    } catch (_) {}

    // 2. Check if GPS Service is Enabled
    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}

    if (!serviceEnabled) {
      _isGpsDisabled = true;
      _currentPosition ??= LocationService.defaultPosition;
      _currentAddress = 'GPS is turned OFF (Showing Default)';
      _isLoading = false;
      notifyListeners();

      if (context != null && context.mounted) {
        LocationService.promptEnableGps(context);
      }
      return;
    }

    _isGpsDisabled = false;

    // 3. Check Permissions
    LocationPermission permission = LocationPermission.denied;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _isPermissionDenied = true;
      _currentPosition ??= LocationService.defaultPosition;
      _currentAddress = 'Location Permission Denied';
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

    // 4. Fetch fresh position: High accuracy GPS with fast Medium (Wi-Fi/Cell) fallback
    try {
      Position? freshPos;
      try {
        freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        // Fallback to cell tower / Wi-Fi network location (fast & works indoors)
        freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      }

      _currentPosition = freshPos;
      final addr = await LocationService.getAddressFromCoordinates(
          freshPos.latitude, freshPos.longitude);
      _currentAddress = addr;
    } catch (_) {
      _currentPosition ??= LocationService.defaultPosition;
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
