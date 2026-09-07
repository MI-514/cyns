import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../customer/rating_review_screen.dart';
import 'agora_call_screen.dart';
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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot>? _requestDocSubscription;
  Timer? _autoMovementTimer;
  bool _isCompletionHandled = false;

  @override
  void initState() {
    super.initState();
    _cLat = widget.request.customerLat;
    _cLng = widget.request.customerLng;
    _wLat = widget.request.workerLat ?? (_cLat + 0.015);
    _wLng = widget.request.workerLng ?? (_cLng + 0.015);
    _updateMarkersAndPolylines();
    _startLiveGpsStream();
    _listenToFirestoreWorkerLocation();
    _startContinuousLiveWorkerNavigation();
  }

  /// Continuous Automatic Live Navigation (Uber/Careem/InDrive style continuous movement)
  void _startContinuousLiveWorkerNavigation() {
    _autoMovementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        return;
      }

      double latDiff = _cLat - _wLat;
      double lngDiff = _cLng - _wLng;

      if (latDiff.abs() < 0.0003 && lngDiff.abs() < 0.0003) {
        _wLat = _cLat;
        _wLng = _cLng;
        timer.cancel();
        _updateMarkersAndPolylines();
        if (mounted && !_isCompletionHandled) {
          _isCompletionHandled = true;
          _showCompletionModal(widget.request);
        }
      } else {
        // Glides worker 15% closer every 3 seconds continuously
        _wLat += latDiff * 0.15;
        _wLng += lngDiff * 0.15;
        _updateMarkersAndPolylines();

        // Smooth camera follow
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_wLat, _wLng)),
        );
      }
    });
  }

  void _listenToFirestoreWorkerLocation() {
    _requestDocSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.serviceRequests)
        .doc(widget.request.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) {
        return;
      }
      final data = doc.data();
      if (data == null) {
        return;
      }

      String status = data['status'] ?? '';
      double? newWLat = (data['workerLat'] as num?)?.toDouble();
      double? newWLng = (data['workerLng'] as num?)?.toDouble();

      if (newWLat != null && newWLng != null) {
        setState(() {
          _wLat = newWLat;
          _wLng = newWLng;
          _updateMarkersAndPolylines();
        });
      }

      if (status == AppConstants.statusCompleted && !_isCompletionHandled) {
        _isCompletionHandled = true;
        _autoMovementTimer?.cancel();
        ServiceRequestModel reqModel =
            ServiceRequestModel.fromMap(data, doc.id);
        _showCompletionModal(reqModel);
      }
    });
  }

  void _showCompletionModal(ServiceRequestModel req) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            size: 56, color: AppColors.statusCompleted),
        title: const Text('Service Completed! 🎉'),
        content: Text(
          '${req.workerName} has arrived and completed your service.\n\nPlease take a moment to rate and review your experience with ${req.workerName}.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.star),
            label: const Text('Rate & Review Worker',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => RatingReviewScreen(request: req),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _startLiveGpsStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) {
        return;
      }
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

    if (mounted) {
      setState(() {});
    }
  }

  void _showCallChoiceModal(BuildContext context, ServiceRequestModel req) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.call, color: AppColors.primaryNavy, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Call ${req.workerName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select how you want to call and talk with the worker:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option 1: In-App Voice Call (Agora VoIP)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.phone_in_talk, color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Internet Voice Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Free internet call inside CYN App'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: req.id,
                      peerName: req.workerName,
                      peerRole: 'worker',
                      isVideoCall: false,
                    ),
                  ),
                );
              },
            ),
            const Divider(),

            // Option 2: In-App Video Call (Agora Video)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.videocam, color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Video Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Live video camera to show issue to worker'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: req.id,
                      peerName: req.workerName,
                      peerRole: 'worker',
                      isVideoCall: true,
                    ),
                  ),
                );
              },
            ),
            const Divider(),

            // Option 3: Direct Phone Call (Cellular Dialer)
            if (req.workerPhone.isNotEmpty)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.availableGreen.withValues(alpha: 0.15),
                  child: const Icon(Icons.phone, color: AppColors.availableGreen),
                ),
                title: const Text('Direct Phone Number Call',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Call ${req.workerPhone} via SIM'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final Uri telUri = Uri(scheme: 'tel', path: req.workerPhone);
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(telUri);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoMovementTimer?.cancel();
    _positionSubscription?.cancel();
    _requestDocSubscription?.cancel();
    _mapController?.dispose();
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
        title: Text('Live Navigation Route - ${req.workerName}'),
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
            onMapCreated: (controller) {
              _mapController = controller;
            },
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

          // Bottom Action Bar for Chat & Call Options
          Positioned(
            bottom: 20,
            left: 14,
            right: 14,
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
                        onPressed: () => _showCallChoiceModal(context, req),
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
