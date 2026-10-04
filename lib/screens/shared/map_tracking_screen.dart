import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/constants/map_constants.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/service_request_provider.dart';
import '../customer/rating_review_screen.dart';
import 'agora_call_screen.dart';
import 'chat_screen.dart';
import '../../core/services/call_signaling_service.dart';
import '../../core/services/notification_service.dart';

/// Full-featured live map tracking screen for Chase Your Need.
///
/// Used by both **Workers** and **Customers**:
/// - Worker sees their own GPS location + customer location + road route + navigation
/// - Customer sees the worker moving toward their location in real-time
///
/// Uses OpenStreetMap tiles (free) and OSRM routing (free, real roads).
class MapTrackingScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const MapTrackingScreen({super.key, required this.request});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  // ── Map ──
  final MapController _mapController = MapController();

  // ── Positions ──
  late double _wLat, _wLng, _cLat, _cLng;

  // ── Route ──
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0;
  int _routeDurationMin = 0;
  bool _isLoadingRoute = false;

  // ── Identity ──
  bool _isWorker = false;
  String? _currentUserId;
  String _currentStatus = '';

  // ── Streams ──
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;

  // ── State ──
  bool _isCompletionHandled = false;
  bool _isUpdatingStatus = false;
  LatLng? _lastRouteCalcPos;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isWorker = _currentUserId == widget.request.workerId;
    _currentStatus = widget.request.status;

    _cLat = widget.request.customerLat;
    _cLng = widget.request.customerLng;
    if (_cLat == 0.0 || _cLng == 0.0) {
      _cLat = MapConstants.defaultLat;
      _cLng = MapConstants.defaultLng;
    }

    _wLat = widget.request.workerLat ?? _cLat;
    _wLng = widget.request.workerLng ?? _cLng;
    if (_wLat == 0.0 || _wLng == 0.0) {
      _wLat = _cLat;
      _wLng = _cLng;
    }

    _fetchRoute();
    _startGpsStream();
    _listenToFirestore();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBothMarkers();
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _firestoreSub?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════
  //  ROUTING (OSRM — free, real roads)
  // ════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);

    try {
      final route = await DirectionsService.getRoute(
        startLat: _wLat,
        startLng: _wLng,
        endLat: _cLat,
        endLng: _cLng,
      );

      if (route != null && mounted) {
        setState(() {
          _routePoints = route.polylinePoints;
          _routeDistanceKm = route.distanceKm;
          _routeDurationMin = route.durationMinutes;
          _isLoadingRoute = false;
        });
        _lastRouteCalcPos = LatLng(_wLat, _wLng);
      } else {
        // Fallback: straight-line with geodesic distance
        double dist =
            LocationService.calculateDistanceKm(_wLat, _wLng, _cLat, _cLng);
        if (mounted) {
          setState(() {
            _routePoints = [LatLng(_wLat, _wLng), LatLng(_cLat, _cLng)];
            _routeDistanceKm = dist;
            _routeDurationMin = LocationService.calculateETA(dist) == 'Arrived'
                ? 0
                : int.tryParse(RegExp(r'(\d+)')
                            .firstMatch(LocationService.calculateETA(dist))
                            ?.group(1) ??
                        '0') ??
                    0;
            _isLoadingRoute = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  void _maybeRecalculateRoute() {
    if (_lastRouteCalcPos == null) {
      _fetchRoute();
      return;
    }

    double movedMeters = Geolocator.distanceBetween(
      _lastRouteCalcPos!.latitude,
      _lastRouteCalcPos!.longitude,
      _wLat,
      _wLng,
    );

    if (movedMeters > MapConstants.routeRecalcThresholdMeters) {
      _fetchRoute();
    }
  }

  // ════════════════════════════════════════════════
  //  LIVE GPS STREAM (Worker tracks & uploads)
  // ════════════════════════════════════════════════

  void _startGpsStream() async {
    // 1. Immediately use last known position so marker appears with zero delay
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted && _isWorker) {
        setState(() {
          _wLat = lastPos.latitude;
          _wLng = lastPos.longitude;
        });
      }
    } catch (_) {}

    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}
    if (!serviceEnabled) return;

    LocationPermission permission = LocationPermission.denied;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // 2. Fetch fresh initial location immediately (doesn't wait for 8m movement!)
    if (_isWorker) {
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      ).then((pos) {
        if (mounted) {
          setState(() {
            _wLat = pos.latitude;
            _wLng = pos.longitude;
          });
          _fitBothMarkers();
        }
      }).catchError((_) {});
    }

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapConstants.distanceFilterMeters,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      if (_isWorker) {
        setState(() {
          _wLat = position.latitude;
          _wLng = position.longitude;
        });

        // Follow worker on map
        try {
          _mapController.move(
            LatLng(_wLat, _wLng),
            _mapController.camera.zoom,
          );
        } catch (_) {}

        // Upload to Firestore
        double dist =
            LocationService.calculateDistanceKm(_wLat, _wLng, _cLat, _cLng);
        String eta = LocationService.calculateETA(dist);

        FirebaseFirestore.instance
            .collection(FirestoreCollections.serviceRequests)
            .doc(widget.request.id)
            .update({
          'workerLat': _wLat,
          'workerLng': _wLng,
          'distanceKm': dist,
          'estimatedArrivalTime': eta,
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});

        // Recalculate route if moved significantly
        _maybeRecalculateRoute();
      }
    });
  }

  // ════════════════════════════════════════════════
  //  FIRESTORE LISTENER (Customer sees worker move)
  // ════════════════════════════════════════════════

  void _listenToFirestore() {
    _firestoreSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.serviceRequests)
        .doc(widget.request.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data();
      if (data == null) return;

      String status = data['status'] ?? '';
      double? newWLat = (data['workerLat'] as num?)?.toDouble();
      double? newWLng = (data['workerLng'] as num?)?.toDouble();

      // Update status
      if (status.isNotEmpty && status != _currentStatus) {
        setState(() => _currentStatus = status);
      }

      // Customer side: update worker position from Firestore
      if (!_isWorker && newWLat != null && newWLng != null) {
        bool workerMoved = (_wLat - newWLat).abs() > 0.00001 ||
            (_wLng - newWLng).abs() > 0.00001;

        if (workerMoved) {
          setState(() {
            _wLat = newWLat;
            _wLng = newWLng;
          });

          // Update route info from Firestore
          double? dist = (data['distanceKm'] as num?)?.toDouble();
          String? eta = data['estimatedArrivalTime'];
          if (dist != null) {
            setState(() {
              _routeDistanceKm = dist;
              if (eta != null) {
                _routeDurationMin = _parseEtaString(eta);
              }
            });
          }

          _maybeRecalculateRoute();
        }
      }

      // Completion handling (customer side)
      if (status == AppConstants.statusCompleted &&
          !_isCompletionHandled &&
          !_isWorker) {
        _isCompletionHandled = true;
        ServiceRequestModel reqModel =
            ServiceRequestModel.fromMap(data, doc.id);
        _showCompletionModal(reqModel);
      }
    });
  }

  int _parseEtaString(String eta) {
    if (eta.contains('h')) {
      final nums =
          RegExp(r'(\d+)').allMatches(eta).map((m) => m.group(1)!).toList();
      if (nums.length >= 2) {
        return (int.tryParse(nums[0]) ?? 0) * 60 + (int.tryParse(nums[1]) ?? 0);
      }
    }
    final match = RegExp(r'(\d+)').firstMatch(eta);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  // ════════════════════════════════════════════════
  //  MAP CONTROLS
  // ════════════════════════════════════════════════

  void _fitBothMarkers() {
    try {
      if (_wLat == 0.0 || _cLat == 0.0) return;
      double minLat = min(_wLat, _cLat) - 0.004;
      double maxLat = max(_wLat, _cLat) + 0.004;
      double minLng = min(_wLng, _cLng) - 0.004;
      double maxLng = max(_wLng, _cLng) + 0.004;

      if ((maxLat - minLat).abs() < 0.006) {
        minLat -= 0.003;
        maxLat += 0.003;
      }
      if ((maxLng - minLng).abs() < 0.006) {
        minLng -= 0.003;
        maxLng += 0.003;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat, minLng),
            LatLng(maxLat, maxLng),
          ),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 240),
        ),
      );
    } catch (_) {}
  }

  void _centerOnWorker() {
    try {
      _mapController.move(LatLng(_wLat, _wLng), MapConstants.trackingZoom);
    } catch (_) {}
  }

  void _centerOnCustomer() {
    try {
      _mapController.move(LatLng(_cLat, _cLng), MapConstants.trackingZoom);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════
  //  STATUS UPDATES
  // ════════════════════════════════════════════════

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final provider =
          Provider.of<ServiceRequestProvider>(context, listen: false);

      double dist =
          LocationService.calculateDistanceKm(_wLat, _wLng, _cLat, _cLng);
      String eta = LocationService.calculateETA(dist);

      await provider.updateStatus(
        requestId: widget.request.id,
        status: newStatus,
        customerId: widget.request.customerId,
        workerId: widget.request.workerId,
        workerLat: _wLat,
        workerLng: _wLng,
        eta: eta,
        distanceKm: dist,
      );
    } catch (_) {}

    if (mounted) setState(() => _isUpdatingStatus = false);
  }

  void _startNavigation() async {
    // Update status to "On the Way"
    await _updateStatus(AppConstants.statusOnTheWay);

    // Launch external turn-by-turn navigation
    LocationService.openTurnByTurnNavigation(_cLat, _cLng);
  }

  void _markArrived() async {
    await _updateStatus(AppConstants.statusArrived);
  }

  void _startWork() async {
    await _updateStatus(AppConstants.statusInProgress);
  }

  void _markCompleted() async {
    final reqProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    final expectedOtp = await reqProvider.ensureCompletionOtp(
      widget.request.id,
      currentOtp: widget.request.completionOtp,
    );

    if (!mounted) return;

    // OTP verification dialog
    String enteredOtp = '';
    bool? success = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon:
            const Icon(Icons.lock_outline, size: 48, color: AppColors.starGold),
        title: const Text('Enter Completion OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ask the customer for the 4-digit Job Completion OTP shown on their screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '0000',
              ),
              onChanged: (v) => enteredOtp = v.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCompleted,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (enteredOtp.trim() == expectedOtp.trim()) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid OTP! Ask the customer again.'),
                    backgroundColor: AppColors.statusRejected,
                  ),
                );
              }
            },
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );

    if (success == true) {
      await _updateStatus(AppConstants.statusCompleted);
    }
  }

  // ════════════════════════════════════════════════
  //  MODALS
  // ════════════════════════════════════════════════

  void _showCompletionModal(ServiceRequestModel req) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            size: 56, color: AppColors.statusCompleted),
        title: const Text('Service Completed! 🎉'),
        content: Text(
          '${req.workerName} has completed your service.\n\nPlease rate and review your experience.',
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

  void _showCallChoiceModal(BuildContext context, ServiceRequestModel req) {
    String peerName = _isWorker ? req.customerName : req.workerName;
    String peerPhone = _isWorker ? req.customerPhone : req.workerPhone;
    String peerRole = _isWorker ? 'customer' : 'worker';
    String peerId = _isWorker ? req.customerId : req.workerId;
    String myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String myName = _isWorker ? req.workerName : req.customerName;

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
                  'Call $peerName',
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
              'Select how you want to call:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // In-App Voice Call
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.phone_in_talk,
                    color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Voice Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Free internet call'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                String signalId = '';
                try {
                  signalId = await CallSignalingService.initiateCall(
                    callerId: myId,
                    callerName: myName,
                    receiverId: peerId,
                    receiverName: peerName,
                    channelId: req.id,
                    isVideo: false,
                  );
                  NotificationService.sendNotification(
                    userId: peerId,
                    title: '📞 Incoming Voice Call from $myName',
                    body: 'Tap to answer call in CYN',
                    type: 'call',
                    relatedId: req.id,
                  );
                } catch (_) {}

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: req.id,
                      peerName: peerName,
                      peerRole: peerRole,
                      isVideoCall: false,
                      signalId: signalId,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            // In-App Video Call
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.videocam, color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Video Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Live video call'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx);
                String signalId = '';
                try {
                  signalId = await CallSignalingService.initiateCall(
                    callerId: myId,
                    callerName: myName,
                    receiverId: peerId,
                    receiverName: peerName,
                    channelId: req.id,
                    isVideo: true,
                  );
                  NotificationService.sendNotification(
                    userId: peerId,
                    title: '📹 Incoming Video Call from $myName',
                    body: 'Tap to answer call in CYN',
                    type: 'call',
                    relatedId: req.id,
                  );
                } catch (_) {}

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: req.id,
                      peerName: peerName,
                      peerRole: peerRole,
                      isVideoCall: true,
                      signalId: signalId,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            // Direct Phone Call
            if (peerPhone.isNotEmpty)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.availableGreen.withValues(alpha: 0.15),
                  child:
                      const Icon(Icons.phone, color: AppColors.availableGreen),
                ),
                title: const Text('Direct Phone Call',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Call $peerPhone via SIM'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final Uri telUri = Uri(scheme: 'tel', path: peerPhone);
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

  // ════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    double straightDist =
        LocationService.calculateDistanceKm(_wLat, _wLng, _cLat, _cLng);
    String distText = _routeDistanceKm > 0
        ? DirectionsService.formatDistance(_routeDistanceKm)
        : LocationService.formatDistance(straightDist);
    String etaText = _routeDurationMin > 0
        ? DirectionsService.formatDuration(_routeDurationMin)
        : LocationService.calculateETA(straightDist);

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. FULL-SCREEN MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (_wLat + _cLat) / 2,
                (_wLng + _cLng) / 2,
              ),
              initialZoom: MapConstants.defaultZoom,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
            ),
            children: [
              // High-speed CartoDB Voyager road tiles with OpenStreetMap fallback
              TileLayer(
                urlTemplate: MapConstants.primaryTileUrl,
                subdomains: MapConstants.primaryTileSubdomains,
                userAgentPackageName: MapConstants.packageName,
                maxZoom: MapConstants.maxZoom,
                fallbackUrl: MapConstants.osmTileUrl,
              ),
              // Road-following route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.accentBlue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  // Customer location marker (Red Home Pin)
                  Marker(
                    point: LatLng(_cLat, _cLng),
                    width: 52,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.home_rounded,
                              color: Colors.white, size: 20),
                        ),
                        CustomPaint(
                          size: const Size(12, 8),
                          painter: _MarkerTipPainter(Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                  // Worker location marker (Blue Navigation Pin)
                  Marker(
                    point: LatLng(_wLat, _wLng),
                    width: 52,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.accentBlue.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 20),
                        ),
                        CustomPaint(
                          size: const Size(12, 8),
                          painter: _MarkerTipPainter(AppColors.accentBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── 2. BACK BUTTON (top-left) ──
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 8),
                child: Material(
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
              ),
            ),
          ),

          // ── 3. TOP INFO CARD ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(60, 8, 14, 0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryNavy, AppColors.lightNavy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + Status Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.pureWhite.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isWorker
                                    ? Icons.home_rounded
                                    : Icons.navigation_rounded,
                                color: AppColors.pureWhite,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isWorker
                                        ? req.customerName
                                        : req.workerName,
                                    style: const TextStyle(
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isWorker
                                        ? req.customerAddress
                                        : req.categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.pureWhite
                                          .withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Distance + ETA row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.straighten_rounded,
                                    color: AppColors.pureWhite
                                        .withValues(alpha: 0.9),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    distText,
                                    style: const TextStyle(
                                      color: AppColors.pureWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 16,
                                width: 1,
                                color:
                                    AppColors.pureWhite.withValues(alpha: 0.3),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_filled,
                                    color: AppColors.starGold,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ETA: $etaText',
                                    style: const TextStyle(
                                      color: AppColors.starGold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLoadingRoute)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppColors.pureWhite,
                                    ),
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
            ),
          ),

          // ── 4. MAP CONTROLS (right side) ──
          Positioned(
            right: 14,
            bottom: 280,
            child: Column(
              children: [
                _mapControlButton(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  onTap: () {
                    try {
                      _mapController.move(
                        _mapController.camera.center,
                        min(_mapController.camera.zoom + 1,
                            MapConstants.maxZoom),
                      );
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 6),
                _mapControlButton(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  onTap: () {
                    try {
                      _mapController.move(
                        _mapController.camera.center,
                        max(_mapController.camera.zoom - 1,
                            MapConstants.minZoom),
                      );
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 12),
                _mapControlButton(
                  heroTag: 'fit_both',
                  icon: Icons.zoom_out_map,
                  color: AppColors.accentBlue,
                  onTap: _fitBothMarkers,
                ),
                const SizedBox(height: 6),
                _mapControlButton(
                  heroTag: 'my_location',
                  icon: Icons.my_location,
                  color: AppColors.primaryNavy,
                  onTap: _isWorker ? _centerOnWorker : _centerOnCustomer,
                ),
              ],
            ),
          ),

          // ── 5. BOTTOM PANEL ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(req),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  BUILD HELPERS
  // ════════════════════════════════════════════════

  Widget _buildStatusBadge() {
    Color badgeColor;
    String badgeText;

    switch (_currentStatus) {
      case AppConstants.statusAccepted:
        badgeColor = AppColors.statusAccepted;
        badgeText = 'ACCEPTED';
        break;
      case AppConstants.statusOnTheWay:
        badgeColor = AppColors.statusOnTheWay;
        badgeText = 'EN ROUTE';
        break;
      case AppConstants.statusArrived:
        badgeColor = AppColors.statusArrived;
        badgeText = 'ARRIVED';
        break;
      case AppConstants.statusInProgress:
        badgeColor = AppColors.statusInProgress;
        badgeText = 'WORKING';
        break;
      case AppConstants.statusCompleted:
        badgeColor = AppColors.statusCompleted;
        badgeText = 'DONE';
        break;
      default:
        badgeColor = AppColors.statusPending;
        badgeText = _currentStatus.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _mapControlButton({
    required String heroTag,
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return Material(
      color: AppColors.pureWhite,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(ServiceRequestModel req) {
    String peerName = _isWorker ? req.customerName : req.workerName;

    return Container(
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Worker-side action buttons ──
              if (_isWorker) ...[
                if (_currentStatus == AppConstants.statusAccepted)
                  _buildActionButton(
                    icon: Icons.navigation_rounded,
                    label: 'Start Navigation',
                    color: AppColors.statusOnTheWay,
                    onTap: _isUpdatingStatus ? null : _startNavigation,
                  ),
                if (_currentStatus == AppConstants.statusOnTheWay)
                  _buildActionButton(
                    icon: Icons.pin_drop_rounded,
                    label: 'I Have Arrived',
                    color: AppColors.statusArrived,
                    onTap: _isUpdatingStatus ? null : _markArrived,
                  ),
                if (_currentStatus == AppConstants.statusArrived)
                  _buildActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Start Work',
                    color: AppColors.statusInProgress,
                    onTap: _isUpdatingStatus ? null : _startWork,
                  ),
                if (_currentStatus == AppConstants.statusInProgress)
                  _buildActionButton(
                    icon: Icons.check_circle_rounded,
                    label: 'Mark as Completed',
                    color: AppColors.statusCompleted,
                    onTap: _isUpdatingStatus ? null : _markCompleted,
                  ),
                if (_currentStatus == AppConstants.statusOnTheWay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusOnTheWay,
                          side:
                              const BorderSide(color: AppColors.statusOnTheWay),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.near_me, size: 18),
                        label: const Text('Open GPS Navigation',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () =>
                            LocationService.openTurnByTurnNavigation(
                                _cLat, _cLng),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],

              // ── Chat + Call Row ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryNavy,
                        side: const BorderSide(color: AppColors.primaryNavy),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18),
                      label: const Text('Chat',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              requestId: req.id,
                              peerName: peerName,
                              peerRole: _isWorker ? 'customer' : 'worker',
                              peerId: _isWorker ? req.customerId : req.workerId,
                              peerPhone: _isWorker
                                  ? req.customerPhone
                                  : req.workerPhone,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.availableGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showCallChoiceModal(context, req),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pureWhite,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Paints a small triangle tip below a map marker.
class _MarkerTipPainter extends CustomPainter {
  final Color color;
  _MarkerTipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTipPainter oldDelegate) =>
      oldDelegate.color != color;
}
