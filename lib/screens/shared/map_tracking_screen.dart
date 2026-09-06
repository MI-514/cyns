import 'package:flutter/material.dart';
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
          title: 'Your Location',
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
        title: Text('Live Arrival - ${req.workerName}'),
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
                                      color: AppColors.availableGreen,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ACCEPTED',
                                      style: TextStyle(
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
                                req.categoryName,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Inner Prominent Box for Distance & ETA
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
                                LocationService.formatDistance(dist),
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
                                'ETA: $eta',
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

          // Bottom Action Bar for Chat & Phone Call
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
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
          ),
        ],
      ),
    );
  }
}
