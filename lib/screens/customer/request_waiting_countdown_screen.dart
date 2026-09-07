import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/map_tracking_screen.dart';

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
    extends State<RequestWaitingCountdownScreen> {
  int _secondsRemaining = 30;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _subscription;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenToRequestStatus();
  }

  void _startTimer() {
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
    _subscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.serviceRequests)
        .doc(widget.request.id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || _isHandled) return;

      final data = doc.data();
      if (data == null) return;

      String status = data['status'] ?? '';

      if (status == AppConstants.statusAccepted) {
        _isHandled = true;
        _timer?.cancel();
        ServiceRequestModel updated = ServiceRequestModel.fromMap(
            data, doc.id);
        _navigateToMapTracking(updated);
      } else if (status == AppConstants.statusRejected) {
        _isHandled = true;
        _timer?.cancel();
        _handleRejection();
      }
    });
  }

  void _simulateWorkerAccept() {
    _timer?.cancel();
    _subscription?.cancel();
    _isHandled = true;

    ServiceRequestModel acceptedReq = ServiceRequestModel(
      id: widget.request.id,
      customerId: widget.request.customerId,
      customerName: widget.request.customerName,
      customerPhone: widget.request.customerPhone,
      workerId: widget.request.workerId,
      workerName: widget.request.workerName,
      workerPhone: widget.request.workerPhone,
      categoryId: widget.request.categoryId,
      categoryName: widget.request.categoryName,
      problemDescription: widget.request.problemDescription,
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
      customerAddress: widget.request.customerAddress,
      workerLat: widget.request.workerLat,
      workerLng: widget.request.workerLng,
      status: AppConstants.statusAccepted,
    );

    _navigateToMapTracking(acceptedReq);
  }

  void _handleTimeout() async {
    if (_isHandled) return;
    _isHandled = true;

    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);

    // Fetch available workers in the category sorted by distance
    await workerProvider.searchWorkers(
      categoryId: widget.request.categoryId,
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
    );

    List<String> updatedAttempted = List.from(widget.attemptedWorkerIds);
    if (!updatedAttempted.contains(widget.request.workerId)) {
      updatedAttempted.add(widget.request.workerId);
    }

    // Filter out workers that were already requested
    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) => !updatedAttempted.contains(w.workerId) && w.isAvailable)
        .toList();

    if (nextWorkers.isNotEmpty) {
      WorkerProfileModel nextWorker = nextWorkers.first;
      if (!mounted) return;

      double dist = LocationService.calculateDistanceKm(
        widget.request.customerLat,
        widget.request.customerLng,
        nextWorker.latitude ?? widget.request.customerLat,
        nextWorker.longitude ?? widget.request.customerLng,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.request.workerName} didn\'t respond in 30s. Auto-dispatching to next nearest worker: ${nextWorker.name} (${LocationService.formatDistance(dist)})...'),
          backgroundColor: AppColors.primaryNavy,
          duration: const Duration(seconds: 3),
        ),
      );

      _sendRequestToNextWorker(nextWorker, updatedAttempted);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.timer_off_outlined,
              size: 48, color: AppColors.statusPending),
          title: const Text('All Nearby Workers Requested'),
          content: const Text(
            'All available nearby workers in this category were requested. No other workers are available nearby right now.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Categories'),
            ),
          ],
        ),
      );
    }
  }

  void _handleRejection() async {
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);

    await workerProvider.searchWorkers(
      categoryId: widget.request.categoryId,
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
    );

    List<String> updatedAttempted = List.from(widget.attemptedWorkerIds);
    if (!updatedAttempted.contains(widget.request.workerId)) {
      updatedAttempted.add(widget.request.workerId);
    }

    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) => !updatedAttempted.contains(w.workerId) && w.isAvailable)
        .toList();

    if (nextWorkers.isNotEmpty) {
      WorkerProfileModel nextWorker = nextWorkers.first;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.request.workerName} was busy. Auto-dispatching to next worker (${nextWorker.name})...'),
          backgroundColor: AppColors.statusPending,
          duration: const Duration(seconds: 3),
        ),
      );

      _sendRequestToNextWorker(nextWorker, updatedAttempted);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.cancel_outlined,
              size: 48, color: AppColors.statusRejected),
          title: const Text('All Workers Requested'),
          content: Text(
            '${widget.request.workerName} declined and no other workers are available nearby right now.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Cancel & View Worker List'),
            ),
          ],
        ),
      );
    }
  }

  void _sendRequestToNextWorker(
      WorkerProfileModel nextWorker, List<String> updatedAttempted) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);

    ServiceRequestModel nextRequest = ServiceRequestModel(
      id: '',
      customerId: auth.userModel?.uid ?? widget.request.customerId,
      customerName: auth.userModel?.fullName ?? widget.request.customerName,
      customerPhone:
          auth.userModel?.phoneNumber ?? widget.request.customerPhone,
      workerId: nextWorker.workerId,
      workerName: nextWorker.name,
      workerPhone: nextWorker.phoneNumber,
      categoryId: widget.request.categoryId,
      categoryName: nextWorker.profession,
      problemDescription:
          'InDrive-Style Auto Hiring Offer for ${nextWorker.profession}',
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
      customerAddress: widget.request.customerAddress,
      workerLat: nextWorker.latitude ?? widget.request.customerLat,
      workerLng: nextWorker.longitude ?? widget.request.customerLng,
      status: AppConstants.statusPending,
    );

    String? reqId = await requestProvider.createRequest(nextRequest);

    if (!mounted) return;

    if (reqId != null) {
      ServiceRequestModel newReq = ServiceRequestModel(
        id: reqId,
        customerId: nextRequest.customerId,
        customerName: nextRequest.customerName,
        customerPhone: nextRequest.customerPhone,
        workerId: nextRequest.workerId,
        workerName: nextRequest.workerName,
        workerPhone: nextRequest.workerPhone,
        categoryId: nextRequest.categoryId,
        categoryName: nextRequest.categoryName,
        problemDescription: nextRequest.problemDescription,
        customerLat: nextRequest.customerLat,
        customerLng: nextRequest.customerLng,
        customerAddress: nextRequest.customerAddress,
        workerLat: nextRequest.workerLat,
        workerLng: nextRequest.workerLng,
        status: nextRequest.status,
      );

      // Auto-restart 30s countdown screen for the next nearest worker!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestWaitingCountdownScreen(
            request: newReq,
            attemptedWorkerIds: updatedAttempted,
          ),
        ),
      );
    }
  }

  void _navigateToMapTracking(ServiceRequestModel updatedRequest) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MapTrackingScreen(request: updatedRequest),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.autorenew, color: AppColors.pureWhite, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'INDRIVE-STYLE AUTO DISPATCH',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.request.workerName,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Searching Nearest ${widget.request.categoryName}',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 36),

              // 30-Second Live Timer Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 30.0,
                      strokeWidth: 10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.pureWhite),
                      backgroundColor:
                          AppColors.pureWhite.withValues(alpha: 0.15),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'SECONDS',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              const Text(
                'Requesting nearest worker...\nIf worker doesn\'t accept in 30s, request will automatically dispatch to the next nearest worker!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),

              // Cancel Request Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.pureWhite,
                  side: const BorderSide(color: AppColors.pureWhite),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.close),
                label: const Text('Cancel Auto-Search'),
                onPressed: () {
                  _timer?.cancel();
                  _subscription?.cancel();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),

              // Test Simulation Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.availableGreen,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  '🧪 Simulate Worker Acceptance (Test Mode)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _simulateWorkerAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
