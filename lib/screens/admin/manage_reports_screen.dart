import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class ManageReportsScreen extends StatefulWidget {
  const ManageReportsScreen({super.key});

  @override
  State<ManageReportsScreen> createState() => _ManageReportsScreenState();
}

class _ManageReportsScreenState extends State<ManageReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Reports & Complaints'),
      ),
      body: admin.allReports.isEmpty
          ? const Center(child: Text('No user reports submitted.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.allReports.length,
              itemBuilder: (context, index) {
                final rep = admin.allReports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.statusRejected.withOpacity(0.1),
                      child: const Icon(Icons.report_problem, color: AppColors.statusRejected),
                    ),
                    title: Text(
                      'Report against: ${rep.reportedUserName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Reason: ${rep.reason}'),
                        Text('Details: ${rep.details}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rep.status == 'Resolved'
                                    ? AppColors.availableGreen.withOpacity(0.15)
                                    : AppColors.statusPending.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                rep.status,
                                style: TextStyle(
                                  color: rep.status == 'Resolved'
                                      ? AppColors.availableGreen
                                      : AppColors.statusPending,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (rep.status != 'Resolved')
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusCompleted,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () {
                                  admin.resolveReport(rep.id);
                                },
                                child: const Text('Mark Resolved', style: TextStyle(fontSize: 11)),
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
