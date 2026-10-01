import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_request_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';
import 'customer_request_status_screen.dart';

class CustomerJobHistoryTab extends StatelessWidget {
  const CustomerJobHistoryTab({super.key});

  Future<void> _clearRequests(
    BuildContext context, {
    required List<ServiceRequestModel> requests,
    required String typeName,
  }) async {
    if (requests.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Clear $typeName Requests?'),
        content: Text(
          'Are you sure you want to permanently delete all $typeName requests (${requests.length}) from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    List<String> ids = requests.map((r) => r.id).toList();

    await requestProvider.deleteMultipleRequests(ids);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared ${ids.length} $typeName requests.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteSingleRequest(
      BuildContext context, ServiceRequestModel req) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Request?'),
        content: Text(
          'Delete request for "${req.categoryName}" from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    await requestProvider.deleteRequest(req.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request deleted.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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
            tabAlignment: TabAlignment.start,
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

            // Active requests: accepted, on the way, arrived, in progress
            final activeReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusAccepted ||
                    r.status == AppConstants.statusOnTheWay ||
                    r.status == AppConstants.statusArrived ||
                    r.status == AppConstants.statusInProgress ||
                    r.status == 'Work Done Pending Confirmation')
                .toList();

            // Pending requests: waiting for worker acceptance
            final pendingReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusPending ||
                    r.status == 'pending')
                .toList();

            // Completed requests
            final completedReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusCompleted ||
                    r.status == 'completed')
                .toList();

            // Cancelled, rejected, or missed requests
            final cancelledReqs = requests
                .where((r) =>
                    r.status == AppConstants.statusCancelled ||
                    r.status == AppConstants.statusRejected ||
                    r.status == AppConstants.statusMissed ||
                    r.status == 'cancelled' ||
                    r.status == 'rejected' ||
                    r.status == 'missed')
                .toList();

            return TabBarView(
              children: [
                _ActiveRequestListView(requests: activeReqs),
                _RequestListView(
                  requests: pendingReqs,
                  emptyText: 'No pending requests.',
                  typeName: 'Pending',
                  onClearAll: pendingReqs.isNotEmpty
                      ? () => _clearRequests(context,
                          requests: pendingReqs, typeName: 'Pending')
                      : null,
                  onDeleteSingle: (req) => _deleteSingleRequest(context, req),
                ),
                _RequestListView(
                  requests: completedReqs,
                  emptyText: 'No completed requests.',
                  typeName: 'Completed',
                  onClearAll: completedReqs.isNotEmpty
                      ? () => _clearRequests(context,
                          requests: completedReqs, typeName: 'Completed')
                      : null,
                  onDeleteSingle: (req) => _deleteSingleRequest(context, req),
                ),
                _RequestListView(
                  requests: cancelledReqs,
                  emptyText: 'No cancelled or rejected requests.',
                  typeName: 'Cancelled',
                  onClearAll: cancelledReqs.isNotEmpty
                      ? () => _clearRequests(context,
                          requests: cancelledReqs, typeName: 'Cancelled')
                      : null,
                  onDeleteSingle: (req) => _deleteSingleRequest(context, req),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Active Requests List View with 1-Tap Chat and Live Map buttons
class _ActiveRequestListView extends StatelessWidget {
  final List<ServiceRequestModel> requests;

  const _ActiveRequestListView({required this.requests});

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusAccepted:
        return AppColors.statusAccepted;
      case AppConstants.statusOnTheWay:
        return AppColors.statusOnTheWay;
      case AppConstants.statusArrived:
        return AppColors.statusArrived;
      case AppConstants.statusInProgress:
        return AppColors.statusInProgress;
      default:
        return AppColors.primaryNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 52, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No active jobs right now.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final statusColor = _getStatusColor(req.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.dividerColor),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category + Status Chip
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppColors.primaryNavy.withValues(alpha: 0.1),
                      child: const Icon(Icons.handyman_rounded,
                          color: AppColors.primaryNavy, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.categoryName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'Technician: ${req.workerName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        req.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (req.customerAddress.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: AppColors.accentBlue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          req.customerAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),

                // Action Buttons: Chat, Live Map, Details
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Chat',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                requestId: req.id,
                                peerName: req.workerName,
                                peerRole: 'worker',
                                peerId: req.workerId,
                                peerPhone: req.workerPhone,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentBlue,
                          side: const BorderSide(
                              color: AppColors.accentBlue, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 16),
                        label: const Text('Live Map',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded,
                          color: AppColors.primaryNavy),
                      tooltip: 'View Details',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerRequestStatusScreen(requestId: req.id),
                          ),
                        );
                      },
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

/// Generic Request List View for Pending, Completed, Cancelled with Clear Options
class _RequestListView extends StatelessWidget {
  final List<ServiceRequestModel> requests;
  final String emptyText;
  final String typeName;
  final VoidCallback? onClearAll;
  final Function(ServiceRequestModel)? onDeleteSingle;

  const _RequestListView({
    required this.requests,
    required this.emptyText,
    required this.typeName,
    this.onClearAll,
    this.onDeleteSingle,
  });

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

    return Column(
      children: [
        // Top Clear All Bar
        if (onClearAll != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.04),
              border: const Border(
                bottom: BorderSide(color: AppColors.dividerColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$typeName Requests (${requests.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.statusRejected,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text('Clear All $typeName',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: onClearAll,
                ),
              ],
            ),
          ),

        // List of requests
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.dividerColor),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primaryNavy.withValues(alpha: 0.1),
                    child: const Icon(Icons.handyman,
                        color: AppColors.primaryNavy, size: 20),
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
                      if (req.problemDescription.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          req.problemDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
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
                      if (onDeleteSingle != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.grey),
                          tooltip: 'Clear',
                          onPressed: () => onDeleteSingle!(req),
                        ),
                      ],
                    ],
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
          ),
        ),
      ],
    );
  }
}
