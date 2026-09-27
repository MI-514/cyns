import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Full-screen incoming call overlay dialog
class IncomingCallDialog extends StatelessWidget {
  final String callerName;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.isVideo,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryNavy.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Caller avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.pureWhite.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                size: 64,
                color: AppColors.pureWhite,
              ),
            ),
            const SizedBox(height: 24),

            // Call type label
            Text(
              isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.pureWhite.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Caller name
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.pureWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'CYN In-App Call',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.pureWhite.withValues(alpha: 0.6),
              ),
            ),

            const Spacer(),

            // Accept / Reject Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject
                  Column(
                    children: [
                      GestureDetector(
                        onTap: onReject,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: AppColors.pureWhite,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Decline',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Accept
                  Column(
                    children: [
                      GestureDetector(
                        onTap: onAccept,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded,
                            color: AppColors.pureWhite,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Accept',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
