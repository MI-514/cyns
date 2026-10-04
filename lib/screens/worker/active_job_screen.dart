import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';

class ActiveJobScreen extends StatefulWidget {
  const ActiveJobScreen({super.key});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  void _callCustomer(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);

    if (auth.userModel == null) {
      return const Center(child: Text('User not logged in.'));
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: requestProvider.getWorkerRequests(auth.userModel!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        final activeList = requests
            .where((r) =>
                r.status == AppConstants.statusAccepted ||
                r.status == AppConstants.statusOnTheWay ||
                r.status == AppConstants.statusArrived ||
                r.status == AppConstants.statusInProgress)
            .toList();

        if (activeList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline,
                    size: 64, color: AppColors.textLight),
                SizedBox(height: 16),
                Text(
                  'No active job right now.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final activeJob = activeList.first;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentBlue),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work,
                        color: AppColors.accentBlue, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Job: ${activeJob.categoryName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'Current Status: ${activeJob.status}',
                            style: const TextStyle(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Customer Details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const Divider(height: 16),
                      Text('Name: ${activeJob.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Phone: ${activeJob.customerPhone}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: AppColors.accentBlue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              activeJob.customerAddress,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        activeJob.problemDescription,
                        style: const TextStyle(
                            color: AppColors.textSecondary, height: 1.4),
                      ),
                      if (activeJob.attachmentUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            activeJob.attachmentUrl!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Status Control Buttons
              const Text(
                'Update Job Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),

              if (activeJob.status == AppConstants.statusAccepted) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOnTheWay,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text(
                      'Start Route & GPS Navigation',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () async {
                      double? wLat = locationProvider.currentPosition?.latitude;
                      double? wLng =
                          locationProvider.currentPosition?.longitude;
                      double dist = LocationService.calculateDistanceKm(
                        wLat ?? 0,
                        wLng ?? 0,
                        activeJob.customerLat,
                        activeJob.customerLng,
                      );
                      String eta = LocationService.calculateETA(dist);

                      await requestProvider.updateStatus(
                        requestId: activeJob.id,
                        status: AppConstants.statusOnTheWay,
                        customerId: activeJob.customerId,
                        workerId: activeJob.workerId,
                        workerLat: wLat,
                        workerLng: wLng,
                        eta: eta,
                        distanceKm: dist,
                      );

                      // Automatically open Turn-by-Turn GPS Navigation
                      LocationService.openTurnByTurnNavigation(
                        activeJob.customerLat,
                        activeJob.customerLng,
                      );
                    },
                  ),
                ),
              ],

              if (activeJob.status == AppConstants.statusOnTheWay) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusArrived),
                    icon: const Icon(Icons.pin_drop),
                    label: const Text('I Have Arrived'),
                    onPressed: () async {
                      await requestProvider.updateStatus(
                        requestId: activeJob.id,
                        status: AppConstants.statusArrived,
                        customerId: activeJob.customerId,
                        workerId: activeJob.workerId,
                      );
                    },
                  ),
                ),
              ],

              if (activeJob.status == AppConstants.statusArrived) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusInProgress),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Work / In Progress'),
                    onPressed: () async {
                      await requestProvider.updateStatus(
                        requestId: activeJob.id,
                        status: AppConstants.statusInProgress,
                        customerId: activeJob.customerId,
                        workerId: activeJob.workerId,
                      );
                    },
                  ),
                ),
              ],

              if (activeJob.status == AppConstants.statusInProgress) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Service as Completed'),
                    onPressed: () async {
                      final workerProvider =
                          Provider.of<WorkerProvider>(context, listen: false);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      final expectedOtp =
                          await requestProvider.ensureCompletionOtp(
                        activeJob.id,
                        currentOtp: activeJob.completionOtp,
                      );

                      if (!context.mounted) return;

                      String enteredOtp = '';
                      bool? success = await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          title: const Text('Enter Completion OTP'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Ask the customer for the 4-digit Job Completion OTP shown on their screen.',
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 8),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: '0000',
                                ),
                                onChanged: (v) => enteredOtp = v.trim(),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusCompleted,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (enteredOtp.trim() == expectedOtp.trim()) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Invalid OTP! Ask the customer again.'),
                                      backgroundColor: AppColors.statusRejected,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Verify & Complete'),
                            ),
                          ],
                        ),
                      );

                      if (success == true) {
                        await requestProvider.updateStatus(
                          requestId: activeJob.id,
                          status: AppConstants.statusCompleted,
                          customerId: activeJob.customerId,
                          workerId: activeJob.workerId,
                        );

                        final profile = workerProvider.currentWorkerProfile;
                        if (profile != null) {
                          await workerProvider.toggleAvailability(
                              profile.workerId, true);
                        }
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Job verified and completed successfully! 🎉'),
                            backgroundColor: AppColors.statusCompleted,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Persistent Primary Chat Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded,
                      color: AppColors.pureWhite, size: 20),
                  label: Text(
                    '💬 Chat with ${activeJob.customerName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          requestId: activeJob.id,
                          peerName: activeJob.customerName,
                          peerRole: 'customer',
                          peerId: activeJob.customerId,
                          peerPhone: activeJob.customerPhone,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Call & Live Map Action Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.availableGreen,
                        side: const BorderSide(color: AppColors.availableGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call Phone',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () =>
                          _callCustomer(context, activeJob.customerPhone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryNavy,
                        side: const BorderSide(color: AppColors.primaryNavy),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Live Map',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MapTrackingScreen(request: activeJob),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Cancel Job Button for Worker
              if (activeJob.status != AppConstants.statusCompleted &&
                  activeJob.status != AppConstants.statusCancelled) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Job',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      bool? confirm = await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Job?'),
                          content: const Text(
                            'Are you sure you want to cancel this job? This will notify the customer and may affect your completion rate.',
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
                              child: const Text('Yes, Cancel Job'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await requestProvider.updateStatus(
                          requestId: activeJob.id,
                          status: AppConstants.statusCancelled,
                          customerId: activeJob.customerId,
                          workerId: activeJob.workerId,
                        );
                        if (context.mounted) {
                          Provider.of<WorkerProvider>(context, listen: false)
                              .toggleAvailability(activeJob.workerId, true)
                              .catchError((_) {});
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
