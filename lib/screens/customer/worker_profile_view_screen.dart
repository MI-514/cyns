import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/sqlite_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/map_tracking_screen.dart';
import 'report_problem_screen.dart';
import 'request_waiting_countdown_screen.dart';

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

  void _directHireWorker() async {
    if (_worker == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final location = Provider.of<LocationProvider>(context, listen: false);
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);

    double cLat = location.currentPosition?.latitude ?? 31.5204;
    double cLng = location.currentPosition?.longitude ?? 74.3587;

    ServiceRequestModel request = ServiceRequestModel(
      id: '',
      customerId: auth.userModel?.uid ?? 'c1',
      customerName: auth.userModel?.fullName ?? 'Customer',
      customerPhone: auth.userModel?.phoneNumber ?? '',
      workerId: _worker!.workerId,
      workerName: _worker!.name,
      workerPhone: _worker!.phoneNumber,
      categoryId: _worker!.categoryIds.isNotEmpty
          ? _worker!.categoryIds.first
          : 'general',
      categoryName: _worker!.profession,
      problemDescription:
          'Direct Location Hiring Offer for ${_worker!.profession}',
      customerLat: cLat,
      customerLng: cLng,
      customerAddress: location.currentAddress,
      workerLat: _worker!.latitude ?? cLat,
      workerLng: _worker!.longitude ?? cLng,
      status: AppConstants.statusPending,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending direct hiring offer to worker...'),
        duration: Duration(seconds: 1),
      ),
    );

    String? reqId = await requestProvider.createRequest(request);

    if (!mounted) return;

    if (reqId != null) {
      request = ServiceRequestModel(
        id: reqId,
        customerId: request.customerId,
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        workerId: request.workerId,
        workerName: request.workerName,
        workerPhone: request.workerPhone,
        categoryId: request.categoryId,
        categoryName: request.categoryName,
        problemDescription: request.problemDescription,
        customerLat: request.customerLat,
        customerLng: request.customerLng,
        customerAddress: request.customerAddress,
        workerLat: request.workerLat,
        workerLng: request.workerLng,
        status: request.status,
      );

      // Directly launch 30s countdown timer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestWaitingCountdownScreen(
            request: request,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage.isNotEmpty
              ? requestProvider.errorMessage
              : 'Failed to send offer.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = Provider.of<LocationProvider>(context);

    double? dist;
    bool hasValidGps = false;
    if (_worker != null &&
        location.currentPosition != null &&
        _worker!.latitude != null &&
        _worker!.longitude != null) {
      dist = location.calculateDistance(_worker!.latitude!, _worker!.longitude!);
      hasValidGps = true;
    }

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
                                    AppColors.primaryNavy.withValues(alpha: 0.1),
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
                                                    .withValues(alpha: 0.15)
                                                : AppColors.unavailableRed
                                                    .withValues(alpha: 0.15),
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

                      // Prominent Location & Distance Details Card
                      Card(
                        color: AppColors.pureWhite,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: AppColors.primaryNavy, width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryNavy,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppColors.pureWhite,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'LOCATION & DISTANCE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accentBlue,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          hasValidGps
                                              ? LocationService.formatDistance(dist!)
                                              : 'GPS Location Off',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasValidGps)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.availableGreen
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⚡ ~${LocationService.calculateETA(dist!)} ETA',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.availableGreen,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.business,
                                      size: 16, color: AppColors.textLight),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Service Area: ${_worker!.workingArea.isNotEmpty ? _worker!.workingArea : "City Wide"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryNavy,
                                    side: const BorderSide(
                                        color: AppColors.primaryNavy),
                                  ),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('View Worker on Live Map'),
                                  onPressed: () {
                                    double cLat =
                                        location.currentPosition?.latitude ??
                                            31.5204;
                                    double cLng =
                                        location.currentPosition?.longitude ??
                                            74.3587;

                                    ServiceRequestModel dummyReq =
                                        ServiceRequestModel(
                                      id: 'map_view',
                                      customerId: 'c1',
                                      customerName: 'Customer',
                                      customerPhone: '',
                                      workerId: _worker!.workerId,
                                      workerName: _worker!.name,
                                      workerPhone: _worker!.phoneNumber,
                                      categoryId: 'cat',
                                      categoryName: _worker!.profession,
                                      problemDescription: '',
                                      customerLat: cLat,
                                      customerLng: cLng,
                                      customerAddress: location.currentAddress,
                                      workerLat: _worker!.latitude ?? cLat,
                                      workerLng: _worker!.longitude ?? cLng,
                                      status: AppConstants.statusAccepted,
                                    );

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MapTrackingScreen(
                                            request: dummyReq),
                                      ),
                                    );
                                  },
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
                                AppColors.primaryNavy.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
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
                        stream: ReviewRepository()
                            .getWorkerReviews(_worker!.workerId),
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

                      const SizedBox(height: 80),
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
                  label: const Text('Hire / Send Request (30s Timer)'),
                  onPressed: _worker!.isAvailable ? _directHireWorker : null,
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
