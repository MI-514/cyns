import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/shared/agora_call_screen.dart';
import '../services/call_signaling_service.dart';
import 'incoming_call_dialog.dart';

class CallListenerWrapper extends StatefulWidget {
  final Widget child;

  const CallListenerWrapper({super.key, required this.child});

  @override
  State<CallListenerWrapper> createState() => _CallListenerWrapperState();
}

class _CallListenerWrapperState extends State<CallListenerWrapper> {
  StreamSubscription<QuerySnapshot>? _callSubscription;
  String? _currentSignalId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCallListener();
    });
  }

  void _initCallListener() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Listen to auth state changes to start/stop listening
    auth.addListener(() {
      if (auth.userModel != null && _callSubscription == null) {
        _startListening(auth.userModel!.uid);
      } else if (auth.userModel == null && _callSubscription != null) {
        _stopListening();
      }
    });

    if (auth.userModel != null) {
      _startListening(auth.userModel!.uid);
    }
  }

  void _startListening(String userId) {
    CallSignalingService.cleanupStaleSignals(userId);

    _callSubscription = CallSignalingService.listenForIncomingCalls(userId)
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Find first ringing call
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
      }
    });
  }

  void _stopListening() {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (BuildContext dialogContext) {
        return IncomingCallDialog(
          callerName: callerName,
          isVideo: isVideo,
          onAccept: () async {
            Navigator.pop(dialogContext); // Close dialog
            await CallSignalingService.acceptCall(signalId);

            if (!mounted) return;

            // Get user role to know what the peer role is
            final auth = Provider.of<AuthProvider>(context, listen: false);
            String peerRole =
                auth.userModel?.role == 'worker' ? 'customer' : 'worker';

            Navigator.push(
              context,
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
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
