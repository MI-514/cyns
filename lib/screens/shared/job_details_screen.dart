import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/service_request_model.dart';

class JobDetailsScreen extends StatelessWidget {
  final ServiceRequestModel request;

  const JobDetailsScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${request.id.substring(0, 6).toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category: ${request.categoryName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${request.status}',
                        style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    Text('Customer: ${request.customerName}'),
                    Text('Customer Phone: ${request.customerPhone}'),
                    const SizedBox(height: 8),
                    Text('Worker: ${request.workerName}'),
                    Text('Worker Phone: ${request.workerPhone}'),
                    const SizedBox(height: 8),
                    Text('Address: ${request.customerAddress}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Problem Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(request.problemDescription),
                    if (request.attachmentUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          request.attachmentUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ]
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
