import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../shared/chat_screen.dart';

class RequestWaitingCountdownScreen extends StatefulWidget {
  final String requestId;
  final String workerName;
  final String workerPhone;

  const RequestWaitingCountdownScreen({
    super.key,
    required this.requestId,
    required this.workerName,
    required this.workerPhone,
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
        .doc(widget.requestId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || _isHandled) return;

      final data = doc.data();
      if (data == null) return;

      String status = data['status'] ?? '';

      if (status == AppConstants.statusAccepted) {
        _isHandled = true;
        _timer?.cancel();
        _navigateToChat();
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
          '${widget.workerName} did not respond within 30 seconds.\n\nYou can call the worker directly or try another available worker.',
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
              final Uri telUri = Uri(scheme: 'tel', path: widget.workerPhone);
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
          '${widget.workerName} is currently busy and declined the request.',
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

  void _navigateToChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          requestId: widget.requestId,
          peerName: widget.workerName,
          peerRole: 'worker',
          peerPhone: widget.workerPhone,
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
                widget.workerName,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

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
                'Request sent successfully.\nIf the worker accepts within 30 seconds, chat and call options will open automatically!',
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
