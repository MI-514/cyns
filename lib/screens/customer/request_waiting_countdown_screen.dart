import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/constants/map_constants.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/chat_screen.dart';

class RequestWaitingCountdownScreen extends StatefulWidget {
  final ServiceRequestModel request;
  final List<String> attemptedWorkerIds;

  const RequestWaitingCountdownScreen({
    super.key,
    required this.request,
    this.attemptedWorkerIds = const [],
  });

  @override
  State<RequestWaitingCountdownScreen> createState() =>
      _RequestWaitingCountdownScreenState();
}

class _RequestWaitingCountdownScreenState
    extends State<RequestWaitingCountdownScreen>
    with SingleTickerProviderStateMixin {
  // ── Map & Radar ──
  final MapController _mapController = MapController();
  late AnimationController _radarController;
  late double _cLat, _cLng;
  late double _wLat, _wLng;
  List<LatLng> _routePoints = [];

  // ── Worker & Request State ──
  late String _currentWorkerId;
  late String _currentWorkerName;
  late List<String> _attemptedWorkerIds;

  int _secondsRemaining = 30;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _subscription;
  bool _isHandled = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();

    _cLat = widget.request.customerLat;
    _cLng = widget.request.customerLng;
    if (_cLat == 0.0 || _cLng == 0.0) {
      _cLat = MapConstants.defaultLat;
      _cLng = MapConstants.defaultLng;
    }

    _currentWorkerId = widget.request.workerId;
    _currentWorkerName = widget.request.workerName;
    _wLat = widget.request.workerLat ?? _cLat;
    _wLng = widget.request.workerLng ?? _cLng;
    if (_wLat == 0.0 || _wLng == 0.0 || (_wLat == _cLat && _wLng == _cLng)) {
      _wLat = _cLat + 0.007;
      _wLng = _cLng + 0.007;
    }

    _attemptedWorkerIds = List.from(widget.attemptedWorkerIds);
    if (_currentWorkerId.isNotEmpty &&
        !_attemptedWorkerIds.contains(_currentWorkerId)) {
      _attemptedWorkerIds.add(_currentWorkerId);
    }

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fetchRoute();
    _startTimer();
    _listenToRequestStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBothMarkers();
    });
  }

  Future<void> _fetchRoute() async {
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
        });
      } else if (mounted) {
        setState(() {
          _routePoints = [LatLng(_wLat, _wLng), LatLng(_cLat, _cLng)];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [LatLng(_wLat, _wLng), LatLng(_cLat, _cLng)];
        });
      }
    }
  }

  void _fitBothMarkers() {
    try {
      final bounds = LatLngBounds.fromPoints([
        LatLng(_cLat, _cLng),
        LatLng(_wLat, _wLng),
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 130,
            bottom: 270,
            left: 50,
            right: 50,
          ),
          maxZoom: 16.0,
        ),
      );
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _listenToRequestStatus() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.serviceRequests)
        .doc(widget.request.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || _isHandled || _isCancelling) return;

      final data = doc.data();
      if (data == null) return;

      String status = data['status'] ?? '';

      if (status == AppConstants.statusAccepted) {
        _isHandled = true;
        _timer?.cancel();
        ServiceRequestModel updated = ServiceRequestModel.fromMap(data, doc.id);
        _navigateToChat(updated);
      } else if (status == AppConstants.statusRejected) {
        _isHandled = true;
        _timer?.cancel();
        _handleRejection();
      } else if (status == AppConstants.statusCancelled) {
        _isHandled = true;
        _timer?.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _handleTimeout() async {
    if (_isHandled || _isCancelling) return;
    _isHandled = true;

    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);

    // Fetch available workers in the category sorted by distance
    await workerProvider.searchWorkers(
      categoryId: widget.request.categoryId,
      customerLat: _cLat,
      customerLng: _cLng,
    );

    // Filter out workers that were already requested
    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) =>
            !_attemptedWorkerIds.contains(w.workerId) && w.isAvailable)
        .toList();

    if (nextWorkers.isNotEmpty) {
      WorkerProfileModel nextWorker = nextWorkers.first;
      if (!mounted) return;

      double dist = LocationService.calculateDistanceKm(
        _cLat,
        _cLng,
        nextWorker.latitude ?? _cLat,
        nextWorker.longitude ?? _cLng,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$_currentWorkerName didn\'t respond in 30s. Auto-transferring to next technician: ${nextWorker.name} (${LocationService.formatDistance(dist)})...'),
          backgroundColor: AppColors.primaryNavy,
          duration: const Duration(seconds: 3),
        ),
      );

      _sendRequestToNextWorker(nextWorker);
    } else {
      if (!mounted) return;
      final requestProvider =
          Provider.of<ServiceRequestProvider>(context, listen: false);
      await requestProvider.updateStatus(
        requestId: widget.request.id,
        status: AppConstants.statusMissed,
        customerId: widget.request.customerId,
        workerId: _currentWorkerId,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.timer_off_outlined,
              size: 48, color: AppColors.statusPending),
          title: const Text('All Nearby Workers Contacted'),
          content: const Text(
            'All available technicians nearby were contacted. No other technicians are active right now.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Service Search'),
            ),
          ],
        ),
      );
    }
  }

  void _handleRejection() async {
    if (_isCancelling) return;
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);

    await workerProvider.searchWorkers(
      categoryId: widget.request.categoryId,
      customerLat: _cLat,
      customerLng: _cLng,
    );

    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) =>
            !_attemptedWorkerIds.contains(w.workerId) && w.isAvailable)
        .toList();

    if (nextWorkers.isNotEmpty) {
      WorkerProfileModel nextWorker = nextWorkers.first;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$_currentWorkerName was busy. Auto-dispatching to next technician (${nextWorker.name})...'),
          backgroundColor: AppColors.statusPending,
          duration: const Duration(seconds: 3),
        ),
      );

      _sendRequestToNextWorker(nextWorker);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.cancel_outlined,
              size: 48, color: AppColors.statusRejected),
          title: const Text('Technicians Unavailable'),
          content: Text(
            '$_currentWorkerName was unavailable and no other technicians are nearby right now.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Search'),
            ),
          ],
        ),
      );
    }
  }

  void _sendRequestToNextWorker(WorkerProfileModel nextWorker) async {
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);

    await requestProvider.reassignRequestToWorker(
      requestId: widget.request.id,
      nextWorker: nextWorker,
      customerName: widget.request.customerName,
    );

    if (!mounted) return;

    setState(() {
      _currentWorkerId = nextWorker.workerId;
      _currentWorkerName = nextWorker.name;
      _wLat = nextWorker.latitude ?? _cLat + 0.007;
      _wLng = nextWorker.longitude ?? _cLng + 0.007;
      if (!_attemptedWorkerIds.contains(nextWorker.workerId)) {
        _attemptedWorkerIds.add(nextWorker.workerId);
      }
      _secondsRemaining = 30;
      _isHandled = false;
    });

    _fetchRoute();
    _startTimer();
    _fitBothMarkers();
  }

  Future<void> _cancelRequest({bool showConfirmDialog = true}) async {
    if (_isCancelling) return;

    if (showConfirmDialog) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Cancel Request?'),
          content: const Text(
            'Are you sure you want to cancel this service request and stop searching for technicians?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Waiting'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRejected,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel Request'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;
    }

    setState(() => _isCancelling = true);
    _timer?.cancel();
    _subscription?.cancel();

    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final requestProvider =
          Provider.of<ServiceRequestProvider>(context, listen: false);
      requestProvider.updateStatus(
        requestId: widget.request.id,
        status: AppConstants.statusCancelled,
        customerId: widget.request.customerId,
        workerId: _currentWorkerId,
      );
    } catch (_) {}

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Service request cancelled.'),
        backgroundColor: AppColors.statusRejected,
        duration: Duration(seconds: 2),
      ),
    );

    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _navigateToChat(ServiceRequestModel updatedRequest) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          requestId: updatedRequest.id,
          peerName: updatedRequest.workerName,
          peerRole: 'worker',
          peerId: updatedRequest.workerId,
          peerPhone: updatedRequest.workerPhone,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dist =
        LocationService.calculateDistanceKm(_cLat, _cLng, _wLat, _wLng);
    String etaText = LocationService.calculateETA(dist);

    return PopScope(
      canPop: _isCancelling,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cancelRequest(showConfirmDialog: true);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ── 1. FULL-SCREEN INTERACTIVE MAP ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  (_cLat + _wLat) / 2,
                  (_cLng + _wLng) / 2,
                ),
                initialZoom: MapConstants.defaultZoom,
                minZoom: MapConstants.minZoom,
                maxZoom: MapConstants.maxZoom,
              ),
              children: [
                // High-speed CartoDB Voyager tiles with OSM fallback
                TileLayer(
                  urlTemplate: MapConstants.primaryTileUrl,
                  subdomains: MapConstants.primaryTileSubdomains,
                  userAgentPackageName: MapConstants.packageName,
                  maxZoom: MapConstants.maxZoom,
                  fallbackUrl: MapConstants.osmTileUrl,
                ),

                // Connecting route polyline
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppColors.primaryNavy,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),

                // Map Markers
                MarkerLayer(
                  markers: [
                    // Customer Pin (Home / Pickup Location)
                    Marker(
                      point: LatLng(_cLat, _cLng),
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar Animated Pulsing Circle
                          AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return Container(
                                width: 44 + (_radarController.value * 40),
                                height: 44 + (_radarController.value * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3 * (1.0 - _radarController.value),
                                  ),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha:
                                          0.6 * (1.0 - _radarController.value),
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.home_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Target Worker Pin
                    Marker(
                      point: LatLng(_wLat, _wLng),
                      width: 110,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Worker Radar Pulse
                          AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return Container(
                                width: 44 + (_radarController.value * 42),
                                height: 44 + (_radarController.value * 42),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryNavy.withValues(
                                    alpha: 0.3 * (1.0 - _radarController.value),
                                  ),
                                  border: Border.all(
                                    color: AppColors.primaryNavy.withValues(
                                      alpha:
                                          0.6 * (1.0 - _radarController.value),
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _currentWorkerName.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.engineering_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── 2. TOP FLOATING APP BAR & STATUS BAR ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: _cancelRequest,
                      tooltip: 'Cancel Request',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'LIVE DISPATCH RADAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category: ${widget.request.categoryName} • 10 KM Search',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Recenter Fit Button
                    IconButton(
                      icon: const Icon(Icons.crop_free_rounded,
                          color: AppColors.starGold, size: 22),
                      tooltip: 'Fit Map View',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: _fitBothMarkers,
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. BOTTOM FLOATING TECHNICIAN & COUNTDOWN CARD ──
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Technician Info Row with 30s Countdown Circle
                    Row(
                      children: [
                        // Live Countdown Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: CircularProgressIndicator(
                                value: _secondsRemaining / 30.0,
                                strokeWidth: 5.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _secondsRemaining <= 10
                                      ? AppColors.statusRejected
                                      : AppColors.primaryNavy,
                                ),
                                backgroundColor: AppColors.dividerColor,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_secondsRemaining',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _secondsRemaining <= 10
                                        ? AppColors.statusRejected
                                        : AppColors.primaryNavy,
                                  ),
                                ),
                                const Text(
                                  'SEC',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Technician Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _currentWorkerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.starGold
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${LocationService.formatDistance(dist)} away',
                                      style: const TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${widget.request.categoryName} • ~$etaText ETA',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Informative Transfer Status Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryNavy.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: AppColors.accentBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pinging technician... Auto-transfers to next technician if no answer in 30s.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.85),
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Prominent Cancel Request Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text(
                          'Cancel Request',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        onPressed: _cancelRequest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
