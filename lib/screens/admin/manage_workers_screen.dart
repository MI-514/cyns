import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class ManageWorkersScreen extends StatelessWidget {
  const ManageWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Workers & Approvals'),
      ),
      body: admin.allWorkers.isEmpty
          ? const Center(child: Text('No worker profiles registered.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.allWorkers.length,
              itemBuilder: (context, index) {
                final worker = admin.allWorkers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
                      child: const Icon(Icons.engineering,
                          color: AppColors.primaryNavy),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            worker.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: worker.isApproved
                                ? AppColors.availableGreen.withOpacity(0.15)
                                : AppColors.statusPending.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            worker.isApproved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              color: worker.isApproved
                                  ? AppColors.availableGreen
                                  : AppColors.statusPending,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Profession: ${worker.profession}'),
                        Text('Phone: ${worker.phoneNumber}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: worker.isApproved
                                    ? AppColors.statusRejected
                                    : AppColors.statusCompleted,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                admin.toggleWorkerApproval(
                                    worker.workerId, worker.isApproved);
                              },
                              child: Text(
                                worker.isApproved ? 'Suspend' : 'Approve Worker',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
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
