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
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Completed'),
              Tab(text: 'Active'),
              Tab(text: 'Rejected'),
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

            final completedReqs = requests
                .where((r) => r.status == AppConstants.statusCompleted)
                .toList();

            final activeReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusAccepted ||
                    r.status == AppConstants.statusOnTheWay ||
                    r.status == AppConstants.statusArrived ||
                    r.status == AppConstants.statusInProgress)
                .toList();

            final rejectedReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusRejected ||
                    r.status == AppConstants.statusCancelled)
                .toList();

            return TabBarView(
              children: [
                _WorkerHistoryList(
                    requests: completedReqs, emptyText: 'No completed jobs yet.'),
                _WorkerHistoryList(
                    requests: activeReqs, emptyText: 'No active jobs.'),
                _WorkerHistoryList(
                    requests: rejectedReqs,
                    emptyText: 'No rejected or cancelled jobs.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkerHistoryList extends StatelessWidget {
  final List<ServiceRequestModel> requests;
  final String emptyText;

  const _WorkerHistoryList({required this.requests, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
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
              backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
              child: const Icon(Icons.build, color: AppColors.primaryNavy),
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
                const SizedBox(height: 4),
                Text(
                  req.customerAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                req.status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
