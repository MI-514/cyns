import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';

class MapTrackingScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const MapTrackingScreen({super.key, required this.request});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    final req = widget.request;

    // Customer Location Marker
    _markers.add(
      Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(req.customerLat, req.customerLng),
        infoWindow: InfoWindow(
          title: 'Customer Location',
          snippet: req.customerAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Worker Location Marker if available
    if (req.workerLat != null && req.workerLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('worker'),
          position: LatLng(req.workerLat!, req.workerLng!),
          infoWindow: InfoWindow(
            title: 'Worker Location (${req.workerName})',
            snippet: 'Status: ${req.status}',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    double dist = 0.0;
    String eta = 'Calculating...';

    if (req.workerLat != null && req.workerLng != null) {
      dist = LocationService.calculateDistanceKm(
        req.workerLat!,
        req.workerLng!,
        req.customerLat,
        req.customerLng,
      );
      eta = req.estimatedArrivalTime ?? LocationService.calculateETA(dist);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Route & Map Tracking'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(req.customerLat, req.customerLng),
              zoom: 14.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // Top Info Banner Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: AppColors.primaryNavy,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: AppColors.pureWhite,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${req.status}',
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            req.workerLat != null
                                ? 'Distance: ${dist.toStringAsFixed(1)} km  •  ETA: $eta'
                                : 'Awaiting worker location updates...',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
