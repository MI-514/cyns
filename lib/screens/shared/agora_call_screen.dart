import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/agora_service.dart';
import '../../core/services/call_signaling_service.dart';

class AgoraCallScreen extends StatefulWidget {
  final String channelId;
  final String peerName;
  final String peerRole;
  final bool isVideoCall;
  final String? signalId; // Firestore call signal doc ID

  const AgoraCallScreen({
    super.key,
    required this.channelId,
    required this.peerName,
    required this.peerRole,
    this.isVideoCall = false,
    this.signalId,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isVideoMuted = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
  StreamSubscription<DocumentSnapshot>? _signalSubscription;
  bool _isCallEnded = false;

  bool _isEngineError = false;
  String _engineErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions
    bool permissionsGranted = await AgoraService.requestCallPermissions(
      isVideo: widget.isVideoCall,
    );

    if (!permissionsGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Microphone/Camera permission is required for calling.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      Navigator.pop(context);
      return;
    }

    if (!AgoraService.isAppIdConfigured) {
      setState(() {
        _isEngineError = true;
        _engineErrorMessage =
            'Agora App ID not configured.\n\nPlease set your Agora App ID in:\nlib/core/services/agora_service.dart\n\nGet one free at console.agora.io';
      });
      return;
    }

    // Listen to call signaling doc for decline / cancel events
    if (widget.signalId != null && widget.signalId!.isNotEmpty) {
      _signalSubscription =
          CallSignalingService.listenToCallSignal(widget.signalId!)
              .listen((doc) {
        if (!doc.exists) return;
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return;
        final status = data['status'];

        if (status == 'rejected') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.peerName} declined the call'),
              backgroundColor: Colors.red,
            ),
          );
          _endCall();
        } else if (status == 'ended' && _remoteUid == null) {
          if (!mounted) return;
          _endCall();
        }
      });

      // 45 seconds ringing timeout
      _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (mounted && _remoteUid == null && !_isCallEnded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No answer from ${widget.peerName}'),
              backgroundColor: Colors.orange,
            ),
          );
          _endCall();
        }
      });
    }

    try {
      _engine = await AgoraService.createEngine();

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
                "Agora Local Joined Channel: ${connection.channelId}, UID: ${connection.localUid}");
            if (!mounted) return;
            setState(() {
              _localUserJoined = true;
            });
            // Start timer if remote peer is already in the channel
            if (_remoteUid != null) {
              _ringingTimeoutTimer?.cancel();
              _startDurationTimer();
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("Agora Remote User Connected: $remoteUid");
            if (!mounted) return;
            _ringingTimeoutTimer?.cancel();
            setState(() {
              _remoteUid = remoteUid;
            });
            // Call is now officially active between both users! Start counting minutes!
            _startDurationTimer();
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint(
                "Agora Remote User Offline: $remoteUid, reason: $reason");
            if (!mounted) return;
            setState(() {
              _remoteUid = null;
            });
            _durationTimer?.cancel();
            // Other user left — end call
            _endCall();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Agora Engine Error [$err]: $msg");
            if (!mounted) return;
            setState(() {
              _isEngineError = true;
              if (err == ErrorCodeType.errInvalidToken ||
                  err == ErrorCodeType.errTokenExpired) {
                _engineErrorMessage = 'Agora Token Error ($err).\n\n'
                    'Agora Console mein ja kar project ka "Primary Certificate" disable karein (Testing Mode: APP ID only) taake kisi token ki zaroorat na rahay aur calls free & lifetime chal sakein.\n\n'
                    'console.agora.io -> Project -> Edit -> Set Security to "App ID only".';
              } else if (err == ErrorCodeType.errInvalidAppId) {
                _engineErrorMessage =
                    'Invalid Agora App ID.\n\nPlease verify your App ID in lib/core/services/agora_service.dart';
              } else {
                _engineErrorMessage = 'Call connection error ($err): $msg';
              }
            });
          },
        ),
      );

      // ── Always Enable Audio for BOTH Voice & Video Calls ──
      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
      await _engine!.muteAllRemoteAudioStreams(false);
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setEnableSpeakerphone(_isSpeaker);

      if (widget.isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      }

      final String token = AgoraService.getTokenForChannel(widget.channelId);
      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideoCall,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideoCall,
        ),
      );
    } catch (e) {
      debugPrint("Agora Init Exception: $e");
      if (!mounted) return;
      setState(() {
        _isEngineError = true;
        _engineErrorMessage = 'Failed to connect call: $e';
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callDurationSeconds++;
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    String m = minutes < 10 ? '0$minutes' : '$minutes';
    String s = seconds < 10 ? '0$seconds' : '$seconds';
    return '$m:$s';
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
    _engine?.setEnableSpeakerphone(_isSpeaker);
  }

  void _toggleVideo() {
    if (!widget.isVideoCall) return;
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    _engine?.muteLocalVideoStream(_isVideoMuted);
  }

  void _switchCamera() {
    if (!widget.isVideoCall) return;
    _engine?.switchCamera();
  }

  void _endCall() async {
    if (_isCallEnded) return;
    _isCallEnded = true;
    _durationTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _signalSubscription?.cancel();
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}

    // End call signal in Firestore
    if (widget.signalId != null && widget.signalId!.isNotEmpty) {
      try {
        await CallSignalingService.endCall(widget.signalId!);
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _signalSubscription?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryNavy,
        body: SafeArea(
          child: Stack(
            children: [
              // Video Call Views or Voice Call Center
              if (_isEngineError)
                _buildErrorView()
              else if (widget.isVideoCall)
                _buildVideoViews()
              else
                _buildVoiceCallCenter(),

              // Top Status Bar
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isVideoCall
                                ? Icons.videocam
                                : Icons.phone_in_talk,
                            color: AppColors.pureWhite,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isVideoCall ? 'Video Call' : 'Voice Call',
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEngineError)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _remoteUid != null
                              ? AppColors.availableGreen.withValues(alpha: 0.85)
                              : Colors.amber.shade800.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _remoteUid != null
                                  ? Icons.fiber_manual_record
                                  : Icons.ring_volume,
                              size: 10,
                              color: AppColors.pureWhite,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _remoteUid != null
                                  ? _formatDuration(_callDurationSeconds)
                                  : 'Ringing...',
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Control Bar (only when call is active)
              if (!_isEngineError)
                Positioned(
                  bottom: 30,
                  left: 12,
                  right: 12,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              _isMuted ? Colors.red : Colors.white24,
                          child: IconButton(
                            icon: Icon(
                              _isMuted ? Icons.mic_off : Icons.mic,
                              color: AppColors.pureWhite,
                              size: 24,
                            ),
                            onPressed: _toggleMute,
                          ),
                        ),
                        const SizedBox(width: 14),
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            icon: const Icon(
                              Icons.call_end,
                              color: AppColors.pureWhite,
                              size: 30,
                            ),
                            onPressed: _endCall,
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (widget.isVideoCall) ...[
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                _isVideoMuted ? Colors.red : Colors.white24,
                            child: IconButton(
                              icon: Icon(
                                _isVideoMuted
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                color: AppColors.pureWhite,
                                size: 24,
                              ),
                              onPressed: _toggleVideo,
                            ),
                          ),
                          const SizedBox(width: 14),
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white24,
                            child: IconButton(
                              icon: const Icon(
                                Icons.cameraswitch,
                                color: AppColors.pureWhite,
                                size: 24,
                              ),
                              onPressed: _switchCamera,
                            ),
                          ),
                        ] else
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _isSpeaker
                                ? AppColors.accentBlue
                                : Colors.white24,
                            child: IconButton(
                              icon: Icon(
                                _isSpeaker ? Icons.volume_up : Icons.volume_off,
                                color: AppColors.pureWhite,
                                size: 24,
                              ),
                              onPressed: _toggleSpeaker,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Error view with clear message and exit button
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_disabled_rounded,
                size: 56,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Call Connection Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.pureWhite,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _engineErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.pureWhite.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Exit Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _endCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCallCenter() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.pureWhite.withValues(alpha: 0.15),
            child: const Icon(
              Icons.person,
              size: 64,
              color: AppColors.pureWhite,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.peerName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.pureWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _remoteUid != null
                ? 'Connected - Talking'
                : (_localUserJoined ? 'Ringing...' : 'Connecting...'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViews() {
    return Stack(
      children: [
        Center(
          child: _remoteUid != null && _engine != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelId),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_outlined,
                        size: 64, color: AppColors.pureWhite),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for ${widget.peerName} to join...',
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
        ),
        if (_localUserJoined && _engine != null && !_isVideoMuted)
          Positioned(
            right: 20,
            top: 80,
            width: 110,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
