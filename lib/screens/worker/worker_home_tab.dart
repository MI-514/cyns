import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/chat_screen.dart';

class WorkerHomeTab extends StatelessWidget {
  const WorkerHomeTab({super.key});

  void _showIssueDetailsModal(BuildContext context, ServiceRequestModel req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customer Issue Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Customer: ${req.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Address: ${req.customerAddress}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Problem Comment / Description:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dividerColor),
              ),
              child: Text(
                req.problemDescription.isNotEmpty
                    ? req.problemDescription
                    : 'No text comment provided.',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            if (req.attachmentUrl != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Attached Issue Photo:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  req.attachmentUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workerProvider = Provider.of<WorkerProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    final worker = workerProvider.currentWorkerProfile;

    if (worker == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Availability Header Card with Gradient
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryNavy, AppColors.lightNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hello, ${worker.name}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: worker.isAvailable
                                  ? AppColors.availableGreen
                                  : AppColors.unavailableRed,
                              boxShadow: [
                                BoxShadow(
                                  color: (worker.isAvailable
                                          ? AppColors.availableGreen
                                          : AppColors.unavailableRed)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        worker.isAvailable
                            ? 'ONLINE • Ready to receive nearby requests'
                            : 'OFFLINE • Toggle switch to start receiving jobs',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Transform.scale(
                  scale: 1.1,
                  child: Switch(
                    value: worker.isAvailable,
                    activeTrackColor: AppColors.availableGreen,
                    activeThumbColor: AppColors.pureWhite,
                    onChanged: (val) {
                      workerProvider.toggleAvailability(worker.workerId, val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Worker Summary Stats Row
          Row(
            children: [
              Expanded(
                child: _WorkerSummaryTile(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.starGold,
                  title: 'Rating',
                  value: '${worker.rating} ★',
                  subtitle: '${worker.reviewCount} Reviews',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkerSummaryTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.availableGreen,
                  title: 'Jobs Done',
                  value: '${worker.completedJobsCount}',
                  subtitle: 'Completed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkerSummaryTile(
                  icon: Icons.work_history_rounded,
                  iconColor: AppColors.accentBlue,
                  title: 'Experience',
                  value: '${worker.experienceYears} Yrs',
                  subtitle: worker.profession,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Incoming Service Requests Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Incoming Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIVE STREAM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBlue,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<ServiceRequestModel>>(
            stream: requestProvider.getWorkerRequests(
              worker.workerId,
              categoryId: worker.categoryIds.isNotEmpty
                  ? worker.categoryIds.first
                  : worker.profession,
              categoryIds: worker.categoryIds,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allRequests = snapshot.data ?? [];
              final pendingRequests = allRequests
                  .where((r) => r.status == AppConstants.statusPending)
                  .toList();

              if (pendingRequests.isNotEmpty) {
                NotificationService.playIncomingJobAlertBeep();
              }

              if (pendingRequests.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_rounded,
                            size: 52, color: AppColors.textLight),
                        const SizedBox(height: 10),
                        const Text(
                          'No new pending requests right now.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Stay online to receive instant doorstep job offers.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (worker.workerId.contains('guest')) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text(
                              '⚡ Create Test Job Request',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final req = ServiceRequestModel(
                                id: 'req_test_${DateTime.now().millisecondsSinceEpoch}',
                                customerId: 'guest_customer_cyn',
                                customerName: 'Ali Raza (Guest Customer)',
                                customerPhone: '+923009876543',
                                workerId: worker.workerId,
                                workerName: worker.name,
                                workerPhone: worker.phoneNumber,
                                categoryId: 'plumber',
                                categoryName: 'Plumbing Service',
                                problemDescription:
                                    'Urgent: Kitchen sink pipe leaking water on floor. Need immediate repair.',
                                customerLat: 31.5204,
                                customerLng: 74.3587,
                                customerAddress:
                                    'House #42, Block B, Gulberg III, Lahore',
                                status: AppConstants.statusPending,
                              );
                              await requestProvider.createRequest(req);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingRequests.length,
                itemBuilder: (context, index) {
                  final req = pendingRequests[index];
                  return Card(
                    elevation: 3,
                    shadowColor: const Color(0x0C0F172A),
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.dividerColor, width: 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Incoming Job Ringer Alert Banner
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.starGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.starGold.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.notifications_active_rounded,
                                    color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '🔔 INCOMING JOB OFFER! Tap Accept to start chat',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                req.categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.statusPending
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'New Request',
                                  style: TextStyle(
                                    color: AppColors.statusPending,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AppColors.primaryNavy.withValues(alpha: 0.1),
                                child: const Icon(Icons.person,
                                    size: 16, color: AppColors.primaryNavy),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                req.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 16, color: AppColors.accentBlue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.customerAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // View Request Issue Details Modal Launcher
                          if (req.problemDescription.isNotEmpty ||
                              req.attachmentUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryNavy,
                                  side: const BorderSide(
                                      color: AppColors.primaryNavy, width: 1.2),
                                  minimumSize: const Size.fromHeight(40),
                                ),
                                icon: const Icon(Icons.find_in_page_rounded,
                                    size: 18),
                                label: const Text(
                                  'View Request Issue Details (Photo & Comment)',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  _showIssueDetailsModal(context, req);
                                },
                              ),
                            ),
                          const SizedBox(height: 6),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.statusRejected,
                                    side: const BorderSide(
                                        color: AppColors.statusRejected, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () async {
                                    await requestProvider.updateStatus(
                                      requestId: req.id,
                                      status: AppConstants.statusRejected,
                                      customerId: req.customerId,
                                      workerId: req.workerId,
                                    );
                                  },
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.statusCompleted,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () async {
                                    await requestProvider.updateStatus(
                                      requestId: req.id,
                                      status: AppConstants.statusAccepted,
                                      customerId: req.customerId,
                                      workerId: req.workerId,
                                    );

                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            requestId: req.id,
                                            peerName: req.customerName,
                                            peerRole: 'customer',
                                            peerPhone: req.customerPhone,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Accept Job'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkerSummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _WorkerSummaryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dividerColor, width: 0.9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
