import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import 'chat_screen.dart';

class MapTrackingScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const MapTrackingScreen({super.key, required this.request});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  late double _wLat;
  late double _wLng;
  late double _cLat;
  late double _cLng;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _cLat = widget.request.customerLat;
    _cLng = widget.request.customerLng;
    _wLat = widget.request.workerLat ?? (_cLat + 0.015);
    _wLng = widget.request.workerLng ?? (_cLng + 0.015);
    _updateMarkersAndPolylines();
    _startLiveGpsStream();
  }

  void _startLiveGpsStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Auto-update every 5 meters moved
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _cLat = position.latitude;
        _cLng = position.longitude;
        _updateMarkersAndPolylines();
      });
    });
  }

  void _updateMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();

    // Customer Location Marker (Red Pin)
    _markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(_cLat, _cLng),
        infoWindow: InfoWindow(
          title: 'Employer Doorstep Location',
          snippet: widget.request.customerAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Worker Location Marker (Blue Pin)
    _markers.add(
      Marker(
        markerId: const MarkerId('worker'),
        position: LatLng(_wLat, _wLng),
        infoWindow: InfoWindow(
          title: 'Worker Location (${widget.request.workerName})',
          snippet: 'En Route to Employer',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Live Route Polyline connecting Worker and Customer
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route_line'),
        points: [
          LatLng(_wLat, _wLng),
          LatLng(_cLat, _cLng),
        ],
        color: AppColors.primaryNavy,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );

    if (mounted) setState(() {});
  }

  void _simulateWorkerMovement() {
    // Step worker 35% closer to customer's exact lat/lng
    double latDiff = _cLat - _wLat;
    double lngDiff = _cLng - _wLng;

    if (latDiff.abs() < 0.0005 && lngDiff.abs() < 0.0005) {
      _wLat = _cLat;
      _wLng = _cLng;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.request.workerName} has arrived at employer doorstep!'),
          backgroundColor: AppColors.availableGreen,
        ),
      );
    } else {
      _wLat += latDiff * 0.35;
      _wLng += lngDiff * 0.35;
    }

    _updateMarkersAndPolylines();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    double dist = LocationService.calculateDistanceKm(
      _wLat,
      _wLng,
      _cLat,
      _cLng,
    );

    String distanceFormatted = LocationService.formatDistance(dist);
    String etaFormatted = LocationService.calculateETA(dist);

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Google Map Route - ${req.workerName}'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_cLat, _cLng),
              zoom: 14.5,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // Top Info Banner Card (Spacious, Wider, & Prominent)
          Positioned(
            top: 16,
            left: 14,
            right: 14,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.pureWhite.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryNavy,
                      AppColors.lightNavy,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.near_me_rounded,
                            color: AppColors.pureWhite,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      req.workerName,
                                      style: const TextStyle(
                                        color: AppColors.pureWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: dist < 0.05
                                          ? AppColors.availableGreen
                                          : AppColors.statusInProgress,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      dist < 0.05 ? 'ARRIVED' : 'EN ROUTE',
                                      style: const TextStyle(
                                        color: AppColors.pureWhite,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Doorstep: ${req.customerAddress}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Inner Prominent Box for Real-Time Distance & ETA
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.pureWhite.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.pureWhite, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                distanceFormatted,
                                style: const TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 20,
                            width: 1,
                            color: AppColors.pureWhite.withValues(alpha: 0.3),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled,
                                  color: AppColors.starGold, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'ETA: $etaFormatted',
                                style: const TextStyle(
                                  color: AppColors.starGold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar for Chat, Phone Call, and Live Simulation
          Positioned(
            bottom: 20,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Test Simulation Button for Worker Moving
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starGold,
                    foregroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.directions_run_rounded, size: 20),
                  label: const Text(
                    '🧪 Test Worker Moving Closer (Simulation)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _simulateWorkerMovement,
                ),
                const SizedBox(height: 8),

                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text('Chat'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    requestId: req.id,
                                    peerName: req.workerName,
                                    peerRole: 'worker',
                                    peerPhone: req.workerPhone,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.availableGreen,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.phone),
                            label: const Text('Call Worker'),
                            onPressed: () async {
                              final Uri telUri =
                                  Uri(scheme: 'tel', path: req.workerPhone);
                              if (await canLaunchUrl(telUri)) {
                                await launchUrl(telUri);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
