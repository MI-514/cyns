import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';

class WorkerHomeTab extends StatelessWidget {
  const WorkerHomeTab({super.key});

  String _getFirstName(String fullName) {
    String clean = fullName.trim();
    if (clean.isNotEmpty && !clean.contains('@')) {
      return clean.split(' ').first;
    }
    return 'Worker';
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
          // Availability Header Card displaying Worker First Name only
          Card(
            color: AppColors.primaryNavy,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${_getFirstName(worker.name)} 🛠️',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          worker.isAvailable
                              ? 'You are ONLINE and receiving nearby job requests.'
                              : 'You are OFFLINE. Switch on to receive requests.',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: worker.isAvailable,
                    activeTrackColor: AppColors.availableGreen,
                    onChanged: (val) {
                      workerProvider.toggleAvailability(worker.workerId, val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Worker Summary Stats
          Row(
            children: [
              Expanded(
                child: _WorkerSummaryTile(
                  title: 'Rating',
                  value: '${worker.rating} ⭐',
                  subtitle: '${worker.reviewCount} reviews',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkerSummaryTile(
                  title: 'Completed',
                  value: '${worker.completedJobsCount}',
                  subtitle: 'Jobs done',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Incoming Service Requests
          const Text(
            'Incoming Service Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<ServiceRequestModel>>(
            stream: requestProvider.getWorkerRequests(worker.workerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allRequests = snapshot.data ?? [];
              final pendingRequests = allRequests
                  .where((r) => r.status == AppConstants.statusPending)
                  .toList();

              if (pendingRequests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 48, color: AppColors.textLight),
                        SizedBox(height: 8),
                        Text(
                          'No new pending requests right now.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                req.categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Customer: ${req.customerName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: AppColors.accentBlue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  req.customerAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.offWhite,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              req.problemDescription,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (req.attachmentUrl != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                req.attachmentUrl!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.statusRejected,
                                    side: const BorderSide(
                                        color: AppColors.statusRejected),
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
                                  ),
                                  onPressed: () async {
                                    await requestProvider.updateStatus(
                                      requestId: req.id,
                                      status: AppConstants.statusAccepted,
                                      customerId: req.customerId,
                                      workerId: req.workerId,
                                    );
                                  },
                                  child: const Text('Accept Request'),
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
  final String title;
  final String value;
  final String subtitle;

  const _WorkerSummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
