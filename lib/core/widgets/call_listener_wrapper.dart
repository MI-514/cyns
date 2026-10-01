import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/shared/agora_call_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../services/audio_alert_service.dart';
import '../services/call_signaling_service.dart';
import '../services/worker_background_service.dart';
import 'incoming_call_dialog.dart';

class CallListenerWrapper extends StatefulWidget {
  final Widget child;

  const CallListenerWrapper({super.key, required this.child});

  @override
  State<CallListenerWrapper> createState() => _CallListenerWrapperState();
}

class _CallListenerWrapperState extends State<CallListenerWrapper> {
  StreamSubscription<QuerySnapshot>? _callSubscription;
  StreamSubscription<DocumentSnapshot>? _activeSignalSubscription;
  BuildContext? _activeDialogContext;
  String? _currentSignalId;
  AuthProvider? _authProvider;
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCallListener();
    });
  }

  void _initCallListener() {
    if (!mounted) return;
    _authProvider = Provider.of<AuthProvider>(context, listen: false);

    _authListener = () {
      final auth = _authProvider;
      if (auth == null) return;
      if (auth.userModel != null && _callSubscription == null) {
        _startListening(auth.userModel!.uid);
      } else if (auth.userModel == null && _callSubscription != null) {
        _stopListening();
      }
    };

    _authProvider?.addListener(_authListener!);

    if (_authProvider?.userModel != null) {
      _startListening(_authProvider!.userModel!.uid);
    }
  }

  void _startListening(String userId) {
    if (userId.isEmpty) return;
    CallSignalingService.cleanupStaleSignals(userId);

    final auth =
        _authProvider ?? Provider.of<AuthProvider>(context, listen: false);
    if (auth.userModel?.role == 'worker') {
      WorkerBackgroundService.instance.startMonitoring(userId);
      WorkerBackgroundService.instance.onNewJobInForeground = () {
        AppConstants.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
                '🔔 New Service Request arrived! Check Incoming Requests.'),
            backgroundColor: AppColors.primaryNavy,
            duration: Duration(seconds: 4),
          ),
        );
      };
    }

    _callSubscription?.cancel();
    _callSubscription = CallSignalingService.listenForIncomingCalls(userId)
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        if (data['status'] == 'ringing' && _currentSignalId != doc.id) {
          _currentSignalId = doc.id;
          _showIncomingCallDialog(
            signalId: doc.id,
            callerName: data['callerName'] ?? 'Unknown Caller',
            isVideo: data['isVideo'] == true,
            channelId: data['channelId'] ?? '',
          );
        }
      } else if (_currentSignalId != null) {
        // Caller canceled or call signal ended before answer
        _dismissIncomingDialog();
      }
    }, onError: (_) {});
  }

  void _dismissIncomingDialog({bool showMissedToast = true}) {
    AudioAlertService.stopAlarmAlert();
    _activeSignalSubscription?.cancel();
    _activeSignalSubscription = null;
    if (_activeDialogContext != null && _activeDialogContext!.mounted) {
      Navigator.of(_activeDialogContext!).pop();
      _activeDialogContext = null;
      if (showMissedToast) {
        AppConstants.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('📞 Missed call'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    _currentSignalId = null;
  }

  void _stopListening() {
    _dismissIncomingDialog(showMissedToast: false);
    WorkerBackgroundService.instance.stopMonitoring();
    _callSubscription?.cancel();
    _callSubscription = null;
    _currentSignalId = null;
  }

  void _showIncomingCallDialog({
    required String signalId,
    required String callerName,
    required bool isVideo,
    required String channelId,
  }) {
    final navContext = AppConstants.navigatorKey.currentContext;
    if (navContext == null) return;

    // Ring alarm sound and vibration for incoming call
    AudioAlertService.playAlarmAlert();

    // Listen to signal status directly to dismiss if caller cancels
    _activeSignalSubscription?.cancel();
    _activeSignalSubscription =
        CallSignalingService.listenToCallSignal(signalId).listen((doc) {
      if (!doc.exists) {
        _dismissIncomingDialog();
        return;
      }
      final data = doc.data() as Map<String, dynamic>?;
      final status = data?['status'];
      if (status == 'ended' || status == 'rejected') {
        _dismissIncomingDialog();
      }
    });

    showDialog(
      context: navContext,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (BuildContext dialogContext) {
        _activeDialogContext = dialogContext;
        return IncomingCallDialog(
          callerName: callerName,
          isVideo: isVideo,
          onAccept: () async {
            AudioAlertService.stopAlarmAlert();
            _activeSignalSubscription?.cancel();
            _activeSignalSubscription = null;
            _activeDialogContext = null;
            Navigator.pop(dialogContext); // Close dialog
            await CallSignalingService.acceptCall(signalId);

            final navState = AppConstants.navigatorKey.currentState;
            final navCtx = AppConstants.navigatorKey.currentContext;
            if (navState == null || navCtx == null || !navCtx.mounted) return;

            final auth = Provider.of<AuthProvider>(navCtx, listen: false);
            String peerRole =
                auth.userModel?.role == 'worker' ? 'customer' : 'worker';

            navState.push(
              MaterialPageRoute(
                builder: (_) => AgoraCallScreen(
                  channelId: channelId,
                  peerName: callerName,
                  peerRole: peerRole,
                  isVideoCall: isVideo,
                  signalId: signalId,
                ),
              ),
            );
            _currentSignalId = null;
          },
          onReject: () async {
            AudioAlertService.stopAlarmAlert();
            _activeSignalSubscription?.cancel();
            _activeSignalSubscription = null;
            _activeDialogContext = null;
            Navigator.pop(dialogContext); // Close dialog
            await CallSignalingService.rejectCall(signalId);
            _currentSignalId = null;
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _dismissIncomingDialog(showMissedToast: false);
    if (_authListener != null && _authProvider != null) {
      _authProvider!.removeListener(_authListener!);
    }
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
