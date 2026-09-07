import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/agora_service.dart';

class AgoraCallScreen extends StatefulWidget {
  final String channelId;
  final String peerName;
  final String peerRole;
  final bool isVideoCall;

  const AgoraCallScreen({
    super.key,
    required this.channelId,
    required this.peerName,
    required this.peerRole,
    this.isVideoCall = false,
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
          content: Text('Microphone/Camera permission is required for calling.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      Navigator.pop(context);
      return;
    }

    try {
      _engine = await AgoraService.createEngine();

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (!mounted) return;
            setState(() {
              _localUserJoined = true;
            });
            _startDurationTimer();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted) return;
            setState(() {
              _remoteUid = null;
            });
          },
        ),
      );

      if (widget.isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
        await _engine!.setEnableSpeakerphone(_isSpeaker);
      }

      await _engine!.joinChannel(
        token: '',
        channelId: widget.channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize call: $e')),
      );
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
    _durationTimer?.cancel();
    await _engine?.leaveChannel();
    await _engine?.release();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Call Views or Voice Call Center
            widget.isVideoCall ? _buildVideoViews() : _buildVoiceCallCenter(),

            // Top Status Bar
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isVideoCall ? Icons.videocam : Icons.phone_in_talk,
                          color: AppColors.pureWhite,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideoCall ? 'In-App Video Call' : 'In-App Voice Call',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.availableGreen.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(_callDurationSeconds),
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Control Bar
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: AppColors.pureWhite,
                        size: 26,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),

                  // End Call Button
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: AppColors.pureWhite,
                        size: 32,
                      ),
                      onPressed: _endCall,
                    ),
                  ),

                  // Speaker/Camera Toggle Button
                  if (widget.isVideoCall)
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: IconButton(
                        icon: const Icon(
                          Icons.cameraswitch,
                          color: AppColors.pureWhite,
                          size: 26,
                        ),
                        onPressed: _switchCamera,
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _isSpeaker
                          ? AppColors.accentBlue
                          : Colors.white24,
                      child: IconButton(
                        icon: Icon(
                          _isSpeaker ? Icons.volume_up : Icons.volume_off,
                          color: AppColors.pureWhite,
                          size: 26,
                        ),
                        onPressed: _toggleSpeaker,
                      ),
                    ),
                ],
              ),
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
            _remoteUid != null ? 'Connected - Talking' : 'Ringing & Connecting...',
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
        // Remote Video View
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
                      'Waiting for ${widget.peerName} to join video call...',
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
        ),

        // Local Video Preview Thumbnail
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
