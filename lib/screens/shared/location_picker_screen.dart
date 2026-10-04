import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/constants/app_colors.dart';
import '../../core/constants/map_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/nominatim_service.dart';

/// Result returned when the user confirms a location.
class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// Full-featured interactive map location picker screen.
///
/// The user can:
/// - Pan/zoom the map to select a location (center pin stays fixed)
/// - Tap "My Location" to jump to their GPS position
/// - Search for an address with live autocomplete suggestions
/// - See the selected address update in real-time via Nominatim (OSM)
/// - Confirm the selected location
///
/// 100% free — uses OpenStreetMap tiles + Nominatim geocoding. No API keys.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late LatLng _selectedPosition;
  String _selectedAddress = 'Move the map to select location...';
  bool _isLoadingAddress = false;
  bool _isSearchVisible = false;
  bool _isLocating = false;
  bool _isSearching = false;
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;

  /// Live autocomplete search suggestions from Nominatim
  List<NominatimPlace> _searchSuggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedPosition = LatLng(
      widget.initialLat ?? MapConstants.defaultLat,
      widget.initialLng ?? MapConstants.defaultLng,
    );

    if (widget.initialLat == null) {
      // No initial position given — detect GPS
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToCurrentLocation();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reverseGeocode(_selectedPosition);
      });
    }

    // Listen to search text changes for live autocomplete
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // GPS & Geocoding
  // ──────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // 1. Immediately pan to last known position if available (Zero wait!)
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          final newPos = LatLng(lastPos.latitude, lastPos.longitude);
          setState(() {
            _selectedPosition = newPos;
          });
          _mapController.move(newPos, MapConstants.pickerZoom);
          _reverseGeocode(newPos);
        }
      } catch (_) {}

      // 2. Check service & permission
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        if (mounted) LocationService.promptEnableGps(context);
        return;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
      } catch (_) {}

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        if (permission == LocationPermission.deniedForever && mounted) {
          LocationService.promptOpenAppSettings(context);
        }
        return;
      }

      // 3. Fresh position with fast fallback (High -> Medium)
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      }

      if (mounted) {
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedPosition = newPos;
          _isLocating = false;
        });
        _mapController.move(newPos, MapConstants.pickerZoom);
        _reverseGeocode(newPos);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// Reverse geocode using Nominatim (OpenStreetMap — free)
  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isLoadingAddress = true);
    try {
      String address = await NominatimService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedAddress =
              'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────
  // Live Autocomplete Search (Nominatim)
  // ──────────────────────────────────────────

  /// Called on every keystroke — debounces, then triggers Nominatim search
  void _onSearchTextChanged() {
    final query = _searchController.text.trim();

    // Clear suggestions if query too short
    if (query.length < 2) {
      if (_searchSuggestions.isNotEmpty) {
        setState(() => _searchSuggestions = []);
      }
      return;
    }

    // Debounce: wait 500ms after user stops typing before searching
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSearchSuggestions(query);
    });
  }

  /// Fetch autocomplete suggestions from Nominatim
  Future<void> _fetchSearchSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final results = await NominatimService.searchPlaces(
        query: query,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _searchSuggestions = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// User tapped a search suggestion — move map to that location
  void _selectSuggestion(NominatimPlace place) {
    final newPos = LatLng(place.lat, place.lng);

    setState(() {
      _selectedPosition = newPos;
      _selectedAddress = place.shortAddress;
      _isLoadingAddress = false;
      _isSearchVisible = false;
      _searchSuggestions = [];
    });

    _searchController.clear();
    FocusScope.of(context).unfocus();
    _mapController.move(newPos, MapConstants.pickerZoom);
  }

  /// User submitted search (pressed enter) — search and go to first result
  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final results = await NominatimService.searchPlaces(
        query: query,
        limit: 1,
      );

      if (results.isNotEmpty && mounted) {
        _selectSuggestion(results.first);
      } else {
        setState(() => _isSearching = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found. Try a different search.'),
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search failed. Check your internet connection.'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _selectedPosition = camera.center;
        _isLoadingAddress = true;
      });

      // Debounce reverse geocoding to avoid excessive API calls
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _reverseGeocode(_selectedPosition);
      });
    }
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _selectedPosition.latitude,
        longitude: _selectedPosition.longitude,
        address: _selectedAddress,
      ),
    );
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearchVisible = false;
      _searchSuggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: MapConstants.pickerZoom,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConstants.primaryTileUrl,
                subdomains: MapConstants.primaryTileSubdomains,
                userAgentPackageName: MapConstants.packageName,
                maxZoom: MapConstants.maxZoom,
                fallbackUrl: MapConstants.osmTileUrl,
              ),
            ],
          ),

          // ── Center Pin (fixed in center of screen) ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryNavy.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.pureWhite,
                      size: 28,
                    ),
                  ),
                  // Pin shadow/tip
                  CustomPaint(
                    size: const Size(16, 10),
                    painter: _PinTipPainter(),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Bar: Back Button + Search ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Back Button
                        Material(
                          color: AppColors.pureWhite,
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.arrow_back,
                                  color: AppColors.primaryNavy, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title or Search Bar
                        Expanded(
                          child: _isSearchVisible
                              ? _buildSearchBar()
                              : Material(
                                  color: AppColors.pureWhite,
                                  elevation: 4,
                                  shadowColor: Colors.black26,
                                  borderRadius: BorderRadius.circular(30),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => _isSearchVisible = true);
                                      _searchFocusNode.requestFocus();
                                    },
                                    borderRadius: BorderRadius.circular(30),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.search,
                                              color: AppColors.textSecondary,
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Search address or place...',
                                            style: TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),

                    // ── Autocomplete Suggestions Dropdown ──
                    if (_searchSuggestions.isNotEmpty && _isSearchVisible)
                      _buildSuggestionsDropdown(),
                  ],
                ),
              ),
            ),
          ),

          // ── My Location FAB ──
          Positioned(
            right: 16,
            bottom: 220,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'picker_my_loc',
                  backgroundColor: AppColors.pureWhite,
                  elevation: 4,
                  onPressed: _isLocating ? null : _goToCurrentLocation,
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryNavy,
                          ),
                        )
                      : const Icon(Icons.my_location,
                          color: AppColors.primaryNavy),
                ),
              ],
            ),
          ),

          // ── Bottom Panel: Address + Confirm ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Label
                      const Text(
                        'Selected Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Address Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryNavy.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isLoadingAddress
                                    ? const Row(
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.accentBlue,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Detecting address...',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _selectedAddress,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedPosition.latitude.toStringAsFixed(5)}, ${_selectedPosition.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed:
                              _isLoadingAddress ? null : _confirmLocation,
                          icon:
                              const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text(
                            'Confirm This Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Search Bar with Live Autocomplete
  // ──────────────────────────────────────────

  Widget _buildSearchBar() {
    return Material(
      color: AppColors.pureWhite,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchAddress(),
              decoration: InputDecoration(
                hintText: 'Search address or place...',
                hintStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: _closeSearch,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Autocomplete Suggestions Dropdown
  // ──────────────────────────────────────────

  Widget _buildSuggestionsDropdown() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: AppColors.pureWhite,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _searchSuggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final place = entry.value;
              final isLast = index == _searchSuggestions.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () => _selectSuggestion(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.accentBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getPlaceIcon(place.type),
                              color: AppColors.accentBlue,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Short name (first part of display name)
                                Text(
                                  place.shortAddress,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                // Full display name
                                Text(
                                  place.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.north_west,
                            size: 14,
                            color: AppColors.textLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 48, endIndent: 14),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Get appropriate icon based on Nominatim place type
  IconData _getPlaceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'city':
      case 'town':
      case 'village':
      case 'municipality':
        return Icons.location_city;
      case 'residential':
      case 'suburb':
      case 'neighbourhood':
        return Icons.holiday_village;
      case 'hospital':
      case 'clinic':
        return Icons.local_hospital;
      case 'school':
      case 'university':
      case 'college':
        return Icons.school;
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return Icons.restaurant;
      case 'mosque':
      case 'church':
      case 'place_of_worship':
        return Icons.account_balance;
      case 'park':
      case 'garden':
        return Icons.park;
      case 'bus_station':
      case 'railway':
      case 'station':
        return Icons.directions_bus;
      case 'aerodrome':
      case 'airport':
        return Icons.flight;
      case 'hotel':
      case 'guest_house':
        return Icons.hotel;
      case 'marketplace':
      case 'mall':
      case 'shop':
        return Icons.shopping_cart;
      default:
        return Icons.location_on;
    }
  }
}

/// Paints a small triangle tip below the center pin marker.
class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primaryNavy;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
