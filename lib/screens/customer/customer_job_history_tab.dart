import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';
import 'customer_request_status_screen.dart';

class CustomerJobHistoryTab extends StatelessWidget {
  const CustomerJobHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    if (auth.userModel == null) {
      return const Center(child: Text('User not authenticated.'));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 0, // Header handled by Dashboard
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: StreamBuilder<List<ServiceRequestModel>>(
          stream: requestProvider.getCustomerRequests(auth.userModel!.uid),
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

            final pendingReqs = requests
                .where((r) => r.status == AppConstants.statusPending)
                .toList();

            final completedReqs = requests
                .where((r) => r.status == AppConstants.statusCompleted)
                .toList();

            final cancelledReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusCancelled ||
                    r.status == AppConstants.statusRejected)
                .toList();

            return TabBarView(
              children: [
                _RequestListView(
                    requests: activeReqs,
                    emptyText: 'No active service requests.'),
                _RequestListView(
                    requests: pendingReqs, emptyText: 'No pending requests.'),
                _RequestListView(
                    requests: completedReqs,
                    emptyText: 'No completed requests.'),
                _RequestListView(
                    requests: cancelledReqs,
                    emptyText: 'No cancelled or rejected requests.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestListView extends StatelessWidget {
  final List<ServiceRequestModel> requests;
  final String emptyText;

  const _RequestListView({required this.requests, required this.emptyText});

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
              backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
              child: const Icon(Icons.handyman, color: AppColors.primaryNavy),
            ),
            title: Text(
              req.categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Worker: ${req.workerName}'),
                const SizedBox(height: 4),
                Text(
                  req.problemDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                req.status,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerRequestStatusScreen(requestId: req.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
