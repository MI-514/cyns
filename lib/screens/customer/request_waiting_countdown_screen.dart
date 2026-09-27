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
        ServiceRequestModel updated = ServiceRequestModel.fromMap(data, doc.id);
        _navigateToChat(updated);
      } else if (status == AppConstants.statusRejected) {
        _isHandled = true;
        _timer?.cancel();
        _handleRejection();
      }
    });
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
      categoryName: widget.request.categoryName, // Keep original requested category name
      problemDescription: widget.request.problemDescription, // Preserve user's typed issue!
      attachmentUrl: widget.request.attachmentUrl, // Preserve attached image!
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dist = LocationService.calculateDistanceKm(
      widget.request.customerLat,
      widget.request.customerLng,
      widget.request.workerLat ?? widget.request.customerLat,
      widget.request.workerLng ?? widget.request.customerLng,
    );

    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.pureWhite),
          onPressed: () {
            _timer?.cancel();
            _subscription?.cancel();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Live Dispatch Radar',
          style: TextStyle(fontSize: 18, color: AppColors.pureWhite),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // Top Dispatch Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.pureWhite.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded,
                        color: AppColors.pureWhite, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'SCANNING 10 KM RADIUS',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Priority Worker Target Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.pureWhite.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.pureWhite,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.engineering_rounded,
                        color: AppColors.primaryNavy,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.request.workerName,
                                  style: const TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.starGold,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${LocationService.formatDistance(dist)} away',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Category: ${widget.request.categoryName}',
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
              ),
              const SizedBox(height: 28),

              // 30-Second Live Timer Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.pureWhite.withValues(alpha: 0.05),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 30.0,
                      strokeWidth: 8,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.pureWhite),
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
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'SECONDS',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Dispatch Status Narrative
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Requesting Nearest Active Worker',
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dispatching to active workers within 10 KM.\nIf not accepted in 30s, automatically rotates to next nearest worker.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Exit / Cancel Auto-Search Button (Properly Constrained & Responsive)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.pureWhite,
                    side: BorderSide(
                      color: AppColors.pureWhite.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Cancel Auto-Search & Exit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    _subscription?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
