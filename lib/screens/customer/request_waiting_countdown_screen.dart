import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../data/models/service_request_model.dart';
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

  void _handleTimeout() {
    if (_isHandled) return;
    _isHandled = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.timer_off_outlined,
            size: 48, color: AppColors.statusPending),
        title: const Text('No Response (30s)'),
        content: Text(
          '${widget.request.workerName} did not respond within 30 seconds.\n\nYou can call the worker directly or try another available worker.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Cancel & Go Back'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
            ),
            icon: const Icon(Icons.phone),
            label: const Text('Call Worker'),
            onPressed: () async {
              Navigator.pop(ctx);
              final Uri telUri =
                  Uri(scheme: 'tel', path: widget.request.workerPhone);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleRejection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined,
            size: 48, color: AppColors.statusRejected),
        title: const Text('Request Declined'),
        content: Text(
          '${widget.request.workerName} is currently busy and declined the request.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
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
