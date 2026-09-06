import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class ManageRequestsScreen extends StatelessWidget {
  const ManageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Service Requests'),
      ),
      body: admin.allRequests.isEmpty
          ? const Center(child: Text('No service requests on platform.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.allRequests.length,
              itemBuilder: (context, index) {
                final req = admin.allRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
                      child: const Icon(Icons.assignment, color: AppColors.primaryNavy),
                    ),
                    title: Text(
                      '${req.categoryName} - Status: ${req.status}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Customer: ${req.customerName} (${req.customerPhone})'),
                        Text('Worker: ${req.workerName} (${req.workerPhone})'),
                        const SizedBox(height: 4),
                        Text(
                          req.problemDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
