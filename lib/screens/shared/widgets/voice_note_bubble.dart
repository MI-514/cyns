import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class VoiceNoteBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSec;
  final bool isMe;
  final String timestampText;

  const VoiceNoteBubble({
    super.key,
    required this.audioUrl,
    required this.durationSec,
    required this.isMe,
    required this.timestampText,
  });

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.durationSec);

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() => _totalDuration = dur);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_position >= _totalDuration && _totalDuration > Duration.zero) {
          await _player.seek(Duration.zero);
        }

        if (widget.audioUrl.startsWith('http://') ||
            widget.audioUrl.startsWith('https://')) {
          await _player.play(UrlSource(widget.audioUrl));
        } else if (widget.audioUrl.startsWith('data:')) {
          final commaIndex = widget.audioUrl.indexOf(',');
          final base64Str = commaIndex != -1
              ? widget.audioUrl.substring(commaIndex + 1)
              : widget.audioUrl;
          final bytes = base64Decode(base64Str);
          await _player.play(BytesSource(bytes));
        } else {
          await _player.play(DeviceFileSource(widget.audioUrl));
        }
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        widget.isMe ? AppColors.pureWhite : AppColors.textPrimary;
    final Color iconBgColor =
        widget.isMe ? AppColors.pureWhite : AppColors.primaryNavy;
    final Color iconColor =
        widget.isMe ? AppColors.primaryNavy : AppColors.pureWhite;

    double progress = 0.0;
    if (_totalDuration.inMilliseconds > 0) {
      progress = (_position.inMilliseconds / _totalDuration.inMilliseconds)
          .clamp(0.0, 1.0);
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play / Pause Circle
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Animated Waveform & Progress slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simulated WhatsApp Waveform bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(18, (index) {
                        // Alternate heights for realistic voice frequencies
                        final heights = [
                          6.0,
                          14.0,
                          22.0,
                          10.0,
                          18.0,
                          26.0,
                          14.0,
                          8.0,
                          20.0,
                          28.0,
                          16.0,
                          22.0,
                          10.0,
                          18.0,
                          14.0,
                          24.0,
                          12.0,
                          8.0
                        ];
                        final h = heights[index % heights.length];
                        final bool isPassed = (index / 18) <= progress;

                        return Container(
                          width: 3.2,
                          height: h,
                          decoration: BoxDecoration(
                            color: isPassed
                                ? (widget.isMe
                                    ? AppColors.starGold
                                    : AppColors.accentBlue)
                                : (widget.isMe
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.35)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),

                    // Duration indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPlaying
                              ? _formatDuration(_position)
                              : _formatDuration(_totalDuration),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.85),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              size: 13,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Voice',
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Message timestamp
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              widget.timestampText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: widget.isMe
                    ? AppColors.pureWhite.withValues(alpha: 0.7)
                    : AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
