import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class AppStatisticsScreen extends StatelessWidget {
  const AppStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    int pendingReqs =
        admin.allRequests.where((r) => r.status == 'Pending').length;
    int completedReqs =
        admin.allRequests.where((r) => r.status == 'Completed').length;
    int activeReqs = admin.allRequests
        .where((r) =>
            r.status == 'Accepted' ||
            r.status == 'On the Way' ||
            r.status == 'Arrived' ||
            r.status == 'In Progress')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Statistics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Activity Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _StatRow(label: 'Total Registered Customers', value: '${admin.totalCustomers}'),
                    const Divider(height: 24),
                    _StatRow(label: 'Total Registered Workers', value: '${admin.totalWorkers}'),
                    const Divider(height: 24),
                    _StatRow(label: 'Total Service Requests', value: '${admin.totalRequests}'),
                    const Divider(height: 24),
                    _StatRow(label: 'Active In-Progress Jobs', value: '$activeReqs'),
                    const Divider(height: 24),
                    _StatRow(label: 'Successfully Completed Jobs', value: '$completedReqs'),
                    const Divider(height: 24),
                    _StatRow(label: 'Pending Service Requests', value: '$pendingReqs'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }
}
