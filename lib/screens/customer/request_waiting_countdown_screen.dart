import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/map_tracking_screen.dart';

class RequestWaitingCountdownScreen extends StatefulWidget {
  final ServiceRequestModel request;

  const RequestWaitingCountdownScreen({
    super.key,
    required this.request,
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
            data as Map<String, dynamic>, doc.id);
        _navigateToMapTracking(updated);
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

    // Fetch next available workers in the same category
    await workerProvider.searchWorkers(
      categoryId: widget.request.categoryId,
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
    );

    // Filter out workers that were already requested
    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) => w.workerId != widget.request.workerId && w.isAvailable)
        .toList();

    WorkerProfileModel? nextWorker =
        nextWorkers.isNotEmpty ? nextWorkers.first : null;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.timer_off_outlined,
            size: 48, color: AppColors.statusPending),
        title: const Text('No Response (30s Timeout)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.request.workerName} did not respond in 30 seconds.',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              nextWorker != null
                  ? 'Would you like to send a hiring request to the next nearby available worker (${nextWorker.name} • ${nextWorker.profession})?'
                  : 'No other available workers found in this category right now. You can call ${widget.request.workerName} directly or view other categories.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (nextWorker != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text('Try Next Worker (${nextWorker.name})'),
              onPressed: () {
                Navigator.pop(ctx);
                _sendRequestToNextWorker(nextWorker);
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.phone),
            label: Text('Call ${widget.request.workerName} Directly'),
            onPressed: () async {
              Navigator.pop(ctx);
              final Uri telUri =
                  Uri(scheme: 'tel', path: widget.request.workerPhone);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              }
            },
          ),
          TextButton(
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

  void _sendRequestToNextWorker(WorkerProfileModel nextWorker) async {
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
          'Direct Location Hiring Offer for ${nextWorker.profession}',
      customerLat: widget.request.customerLat,
      customerLng: widget.request.customerLng,
      customerAddress: widget.request.customerAddress,
      workerLat: nextWorker.latitude ?? widget.request.customerLat,
      workerLng: nextWorker.longitude ?? widget.request.customerLng,
      status: AppConstants.statusPending,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sending hiring request to ${nextWorker.name}...'),
        duration: const Duration(seconds: 1),
      ),
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

      // Replace with new 30-second countdown screen for the next worker!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestWaitingCountdownScreen(request: newReq),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage.isNotEmpty
              ? requestProvider.errorMessage
              : 'Failed to send offer to next worker.'),
          backgroundColor: AppColors.statusRejected,
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

    List<WorkerProfileModel> nextWorkers = workerProvider.searchResults
        .where((w) => w.workerId != widget.request.workerId && w.isAvailable)
        .toList();

    WorkerProfileModel? nextWorker =
        nextWorkers.isNotEmpty ? nextWorkers.first : null;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined,
            size: 48, color: AppColors.statusRejected),
        title: const Text('Request Declined'),
        content: Text(
          nextWorker != null
              ? '${widget.request.workerName} is currently busy and declined the request.\n\nWould you like to try the next available worker (${nextWorker.name})?'
              : '${widget.request.workerName} is currently busy and declined the request.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (nextWorker != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text('Try Next Worker (${nextWorker.name})'),
              onPressed: () {
                Navigator.pop(ctx);
                _sendRequestToNextWorker(nextWorker);
              },
            ),
          TextButton(
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
              const Text(
                'WAITING FOR WORKER RESPONSE',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
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
                widget.request.categoryName,
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
              const SizedBox(height: 40),

              const Text(
                'Direct Hiring Offer Sent!\nWhen worker accepts within 30s, live map route, distance, and ETA will open immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Cancel Request Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.pureWhite,
                  side: const BorderSide(color: AppColors.pureWhite),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.close),
                label: const Text('Cancel Request'),
                onPressed: () {
                  _timer?.cancel();
                  _subscription?.cancel();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
