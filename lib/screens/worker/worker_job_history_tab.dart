import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';

class WorkerJobHistoryTab extends StatelessWidget {
  const WorkerJobHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    if (auth.userModel == null) {
      return const Center(child: Text('User not logged in.'));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 48,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active Jobs'),
              Tab(text: 'Rejected Jobs'),
              Tab(text: 'Missed Requests'),
            ],
          ),
        ),
        body: StreamBuilder<List<ServiceRequestModel>>(
          stream: requestProvider.getWorkerRequests(auth.userModel!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data ?? [];

            final activeReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusAccepted ||
                    r.status == AppConstants.statusOnTheWay ||
                    r.status == AppConstants.statusArrived ||
                    r.status == AppConstants.statusInProgress)
                .toList();

            final rejectedReqs = requests
                .where((r) => r.status == AppConstants.statusRejected)
                .toList();

            final missedReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusCancelled ||
                    r.status == 'missed')
                .toList();

            return TabBarView(
              children: [
                _ActiveJobsList(requests: activeReqs),
                _RejectedJobsList(requests: rejectedReqs),
                _MissedRequestsList(requests: missedReqs),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveJobsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _ActiveJobsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'No active jobs right now.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
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
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusInProgress.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        req.status,
                        style: const TextStyle(
                          color: AppColors.statusInProgress,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Customer: ${req.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(req.customerAddress,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                        onPressed: () {
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
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                        ),
                        icon: const Icon(Icons.map),
                        label: const Text('Live Map'),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RejectedJobsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _RejectedJobsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'No rejected jobs.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppColors.statusRejected.withValues(alpha: 0.15),
              child: const Icon(Icons.cancel, color: AppColors.statusRejected),
            ),
            title: Text(
              req.categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Customer: ${req.customerName}'),
                const SizedBox(height: 2),
                Text(
                  req.customerAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusRejected.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Rejected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusRejected,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissedRequestsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _MissedRequestsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'No missed requests.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppColors.statusPending.withValues(alpha: 0.15),
              child: const Icon(Icons.call_missed, color: AppColors.statusPending),
            ),
            title: const Text(
              'Missed Request',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.statusPending,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Missed request from ${req.customerName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusPending.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Missed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusPending,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
