import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/sqlite_service.dart';
import '../../data/models/worker_profile_model.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/models/review_model.dart';
import '../../providers/worker_provider.dart';
import 'create_service_request_screen.dart';
import 'report_problem_screen.dart';

class WorkerProfileViewScreen extends StatefulWidget {
  final String workerId;

  const WorkerProfileViewScreen({super.key, required this.workerId});

  @override
  State<WorkerProfileViewScreen> createState() =>
      _WorkerProfileViewScreenState();
}

class _WorkerProfileViewScreenState extends State<WorkerProfileViewScreen> {
  WorkerProfileModel? _worker;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    await workerProvider.fetchWorkerProfile(widget.workerId);
    setState(() {
      _worker = workerProvider.currentWorkerProfile;
      _isLoading = false;
    });

    if (_worker != null) {
      // Save in SQLite recently viewed workers
      SqliteService.instance.saveRecentWorker(
        workerId: _worker!.workerId,
        name: _worker!.name,
        profession: _worker!.profession,
        rating: _worker!.rating,
        profilePicUrl: _worker!.profilePicUrl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Profile'),
        actions: [
          if (_worker != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Report Worker',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportProblemScreen(
                      reportedUserId: _worker!.workerId,
                      reportedUserName: _worker!.name,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _worker == null
              ? const Center(child: Text('Worker profile not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor:
                                    AppColors.primaryNavy.withOpacity(0.1),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primaryNavy,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _worker!.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _worker!.profession,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accentBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _worker!.isAvailable
                                                ? AppColors.availableGreen
                                                    .withOpacity(0.15)
                                                : AppColors.unavailableRed
                                                    .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _worker!.isAvailable
                                                ? 'Available Now'
                                                : 'Currently Unavailable',
                                            style: TextStyle(
                                              color: _worker!.isAvailable
                                                  ? AppColors.availableGreen
                                                  : AppColors.unavailableRed,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.star,
                              iconColor: AppColors.starGold,
                              title: 'Rating',
                              value: '${_worker!.rating} (${_worker!.reviewCount})',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.work_history,
                              iconColor: AppColors.accentBlue,
                              title: 'Jobs Done',
                              value: '${_worker!.completedJobsCount}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.badge,
                              iconColor: AppColors.statusInProgress,
                              title: 'Experience',
                              value: '${_worker!.experienceYears} Years',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Service Description
                      const Text(
                        'Service Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _worker!.serviceDescription.isNotEmpty
                            ? _worker!.serviceDescription
                            : 'No service description provided.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Skills List
                      const Text(
                        'Skills & Specialties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _worker!.skills.map((skill) {
                          return Chip(
                            label: Text(skill),
                            backgroundColor:
                                AppColors.primaryNavy.withOpacity(0.08),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Working Area
                      const Text(
                        'Working Area',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.accentBlue, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            _worker!.workingArea.isNotEmpty
                                ? _worker!.workingArea
                                : 'City Wide Support',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Reviews List Section
                      const Text(
                        'Customer Reviews',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),

                      StreamBuilder<List<ReviewModel>>(
                        stream: ReviewRepository().getWorkerReviews(_worker!.workerId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final reviews = snapshot.data ?? [];
                          if (reviews.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'No reviews yet for this worker.',
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final rev = reviews[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(rev.customerName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(rev.reviewText),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star,
                                          color: AppColors.starGold, size: 16),
                                      Text('${rev.rating}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 80), // Space for bottom button
                    ],
                  ),
                ),

      bottomSheet: _worker == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Hire / Send Request'),
                  onPressed: _worker!.isAvailable
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateServiceRequestScreen(
                                worker: _worker!,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
