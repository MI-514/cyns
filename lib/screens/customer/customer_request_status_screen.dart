import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/service_request_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';
import 'worker_profile_view_screen.dart';
import 'rating_review_screen.dart';

class CustomerRequestStatusScreen extends StatelessWidget {
  final String requestId;

  const CustomerRequestStatusScreen({super.key, required this.requestId});

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return AppColors.statusPending;
      case AppConstants.statusAccepted:
        return AppColors.statusAccepted;
      case AppConstants.statusOnTheWay:
        return AppColors.statusOnTheWay;
      case AppConstants.statusArrived:
        return AppColors.statusArrived;
      case AppConstants.statusInProgress:
        return AppColors.statusInProgress;
      case AppConstants.statusCompleted:
        return AppColors.statusCompleted;
      case AppConstants.statusRejected:
        return AppColors.statusRejected;
      case AppConstants.statusCancelled:
        return AppColors.statusCancelled;
      default:
        return AppColors.primaryNavy;
    }
  }

  void _callWorker(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Request Status'),
      ),
      body: StreamBuilder<ServiceRequestModel?>(
        stream: requestProvider.getRequestStream(requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final req = snapshot.data;
          if (req == null) {
            return const Center(child: Text('Service request not found.'));
          }

          final statusColor = _getStatusColor(req.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        req.status == AppConstants.statusCompleted
                            ? Icons.check_circle
                            : req.status == AppConstants.statusRejected ||
                                    req.status == AppConstants.statusCancelled
                                ? Icons.cancel
                                : Icons.hourglass_top,
                        size: 48,
                        color: statusColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        req.status,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Category: ${req.categoryName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stepper Visualizer
                _StatusStepper(currentStatus: req.status),
                const SizedBox(height: 24),

                // Worker Details Card
                Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerProfileViewScreen(
                            workerId: req.workerId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Assigned Worker',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              const Text(
                                'View Profile →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentBlue,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    AppColors.primaryNavy.withValues(alpha: 0.1),
                                child: const Icon(Icons.person,
                                    color: AppColors.primaryNavy),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.workerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      req.workerPhone,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Problem Description
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Problem Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          req.problemDescription,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (req.attachmentUrl != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              req.attachmentUrl!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                if (req.completionOtp != null &&
                    req.status != AppConstants.statusCompleted &&
                    req.status != AppConstants.statusCancelled &&
                    req.status != AppConstants.statusRejected) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.starGold.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.starGold, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job Completion OTP',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Share this 4-digit code with the worker only when the job is fully complete.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.starGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              req.completionOtp!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action Buttons based on status
                if (req.status != AppConstants.statusPending &&
                    req.status != AppConstants.statusRejected &&
                    req.status != AppConstants.statusCancelled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call),
                          label: const Text('Call Worker'),
                          onPressed: () =>
                              _callWorker(context, req.workerPhone),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  requestId: req.id,
                                  peerName: req.workerName,
                                  peerRole: 'worker',
                                  peerId: req.workerId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Track Location / View Map'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapTrackingScreen(request: req),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Rate Worker Button after completion
                if (req.status == AppConstants.statusCompleted &&
                    !req.hasBeenReviewed) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starGold,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.star),
                      label: const Text('Rate & Review Worker'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RatingReviewScreen(request: req),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                if (req.status != AppConstants.statusCompleted &&
                    req.status != AppConstants.statusCancelled &&
                    req.status != AppConstants.statusRejected) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusRejected,
                        side: const BorderSide(color: AppColors.statusRejected),
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Request'),
                      onPressed: () async {
                        bool? confirm = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancel Job?'),
                            content: const Text(
                              'Are you sure you want to cancel this request? If the worker is already on the way, this may affect your profile rating.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No, Keep It'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusRejected,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Yes, Cancel'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await requestProvider.updateStatus(
                            requestId: req.id,
                            status: AppConstants.statusCancelled,
                            customerId: req.customerId,
                            workerId: req.workerId,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String currentStatus;

  const _StatusStepper({required this.currentStatus});

  static const List<String> steps = [
    AppConstants.statusPending,
    AppConstants.statusAccepted,
    AppConstants.statusOnTheWay,
    AppConstants.statusArrived,
    AppConstants.statusInProgress,
    AppConstants.statusCompleted,
  ];

  int _getStepIndex() {
    int idx = steps.indexOf(currentStatus);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    int currentStep = _getStepIndex();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Progress Tracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: List.generate(steps.length, (index) {
                bool isDone = index <= currentStep;
                bool isCurrent = index == currentStep;
                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? AppColors.primaryNavy
                                : AppColors.dividerColor,
                          ),
                          child: isDone
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        if (index < steps.length - 1)
                          Container(
                            width: 2,
                            height: 24,
                            color: index < currentStep
                                ? AppColors.primaryNavy
                                : AppColors.dividerColor,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index],
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isDone
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
