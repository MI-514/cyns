import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';

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
              Tab(text: 'Done Jobs'),
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

            final doneReqs = requests
                .where((r) => r.status == AppConstants.statusCompleted)
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
                _DoneJobsList(requests: doneReqs),
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

class _DoneJobsList extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _DoneJobsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'No completed jobs yet.',
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
              backgroundColor: AppColors.availableGreen.withValues(alpha: 0.15),
              child: const Icon(Icons.check_circle, color: AppColors.availableGreen),
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
                color: AppColors.availableGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.availableGreen,
                ),
              ),
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
