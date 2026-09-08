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
import '../shared/agora_call_screen.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';

class ActiveJobScreen extends StatefulWidget {
  const ActiveJobScreen({super.key});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  void _showCallChoiceModal(BuildContext context, ServiceRequestModel job) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.call, color: AppColors.primaryNavy, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Call ${job.customerName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select how you want to call and talk with the customer:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option 1: In-App Voice Call (Agora VoIP)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.phone_in_talk, color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Internet Voice Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Free internet call inside CYN App'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: job.id,
                      peerName: job.customerName,
                      peerRole: 'customer',
                      isVideoCall: false,
                    ),
                  ),
                );
              },
            ),
            const Divider(),

            // Option 2: In-App Video Call (Agora Video)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                child: const Icon(Icons.videocam, color: AppColors.primaryNavy),
              ),
              title: const Text('In-App Video Call',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Live video camera call with customer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgoraCallScreen(
                      channelId: job.id,
                      peerName: job.customerName,
                      peerRole: 'customer',
                      isVideoCall: true,
                    ),
                  ),
                );
              },
            ),
            const Divider(),

            // Option 3: Direct Phone Call (Cellular Dialer)
            if (job.customerPhone.isNotEmpty)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.availableGreen.withValues(alpha: 0.15),
                  child: const Icon(Icons.phone, color: AppColors.availableGreen),
                ),
                title: const Text('Direct Phone Number Call',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Call ${job.customerPhone} via SIM'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final Uri telUri = Uri(scheme: 'tel', path: job.customerPhone);
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(telUri);
                  }
                },
              ),
          ],
        ),
      ),
    );
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
                Icon(Icons.play_circle_outline, size: 64, color: AppColors.textLight),
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
                    const Icon(Icons.work, color: AppColors.accentBlue, size: 30),
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
                        backgroundColor: AppColors.statusOnTheWay),
                    icon: const Icon(Icons.directions_run),
                    label: const Text('I am On The Way'),
                    onPressed: () async {
                      double? wLat = locationProvider.currentPosition?.latitude;
                      double? wLng = locationProvider.currentPosition?.longitude;
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
                      await requestProvider.updateStatus(
                        requestId: activeJob.id,
                        status: AppConstants.statusCompleted,
                        customerId: activeJob.customerId,
                        workerId: activeJob.workerId,
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Call / Chat / Map Action Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text('Call Customer'),
                      onPressed: () =>
                          _showCallChoiceModal(context, activeJob),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              requestId: activeJob.id,
                              peerName: activeJob.customerName,
                              peerRole: 'customer',
                              peerPhone: activeJob.customerPhone,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open Map / Share Live Location'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapTrackingScreen(request: activeJob),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
