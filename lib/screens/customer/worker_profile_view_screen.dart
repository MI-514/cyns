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
import '../../core/widgets/worker_badge_widget.dart';

class WorkerProfileViewScreen extends StatefulWidget {
  final String workerId;
  final WorkerProfileModel? worker;

  const WorkerProfileViewScreen({
    super.key,
    required this.workerId,
    this.worker,
  });

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
    _worker = widget.worker;
    _isLoading = widget.worker == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  void _loadProfile() async {
    try {
      final workerProvider =
          Provider.of<WorkerProvider>(context, listen: false);
      await workerProvider.fetchWorkerProfile(widget.workerId);
      if (!mounted) return;

      setState(() {
        _worker = workerProvider.currentWorkerProfile ?? _worker;
        _isLoading = false;
      });

      if (_worker != null) {
        // Save in SQLite recently viewed workers safely
        try {
          await SqliteService.instance.saveRecentWorker(
            workerId: _worker!.workerId,
            name: _worker!.name,
            profession: _worker!.profession,
            rating: _worker!.rating,
            profilePicUrl: _worker!.profilePicUrl,
          );
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      dist =
          location.calculateDistance(_worker!.latitude!, _worker!.longitude!);
      hasValidGps = dist > 0 ||
          (dist == 0 &&
              location.currentPosition!.latitude == _worker!.latitude);
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
                        elevation: 3,
                        shadowColor: const Color(0x0C0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                              color: AppColors.dividerColor, width: 1.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppColors.primaryNavy
                                    .withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primaryNavy,
                                  size: 42,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _worker!.name,
                                            style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.verified_rounded,
                                            color: AppColors.accentBlue,
                                            size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _worker!.profession,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _worker!.isAvailable
                                            ? AppColors.availableGreen
                                                .withValues(alpha: 0.15)
                                            : AppColors.unavailableRed
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
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
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    WorkerBadgeRow(worker: _worker!),
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
                        elevation: 3,
                        shadowColor: const Color(0x0C0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                              color: AppColors.primaryNavy, width: 1.2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryNavy,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: AppColors.pureWhite,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'LOCATION & DISTANCE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.accentBlue,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          (hasValidGps && dist != null)
                                              ? LocationService.formatDistance(
                                                  dist)
                                              : 'GPS Location Off',
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasValidGps && dist != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.availableGreen
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '⚡ ~${LocationService.calculateETA(dist)} ETA',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.availableGreen,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(Icons.business_rounded,
                                      size: 18, color: AppColors.textLight),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Service Area: ${_worker!.workingArea.isNotEmpty ? _worker!.workingArea : "City Wide"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryNavy,
                                    side: const BorderSide(
                                        color: AppColors.primaryNavy,
                                        width: 1.5),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  icon: const Icon(Icons.map_rounded, size: 18),
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
                              icon: Icons.star_rounded,
                              iconColor: AppColors.starGold,
                              title: 'Rating',
                              value:
                                  '${_worker!.rating} (${_worker!.reviewCount})',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.work_history_rounded,
                              iconColor: AppColors.accentBlue,
                              title: 'Jobs Done',
                              value: '${_worker!.completedJobsCount}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.badge_rounded,
                              iconColor: AppColors.statusInProgress,
                              title: 'Experience',
                              value: '${_worker!.experienceYears} Years',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Service Description
                      const Text(
                        'Service Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.dividerColor),
                        ),
                        child: Text(
                          _worker!.serviceDescription.isNotEmpty
                              ? _worker!.serviceDescription
                              : 'No service description provided.',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Skills List
                      const Text(
                        'Skills & Specialties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _worker!.skills.map((skill) {
                          return Chip(
                            label: Text(skill),
                            backgroundColor:
                                AppColors.primaryNavy.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: const TextStyle(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 10),

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
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.pureWhite,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: AppColors.dividerColor),
                              ),
                              child: const Text(
                                'No customer reviews yet for this worker.',
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
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                      color: AppColors.dividerColor,
                                      width: 0.8),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryNavy
                                        .withValues(alpha: 0.1),
                                    child: const Icon(Icons.person,
                                        color: AppColors.primaryNavy),
                                  ),
                                  title: Text(
                                    rev.customerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(rev.reviewText),
                                      if (rev.tags.isNotEmpty ||
                                          rev.tipAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: rev.tags
                                              .map((tag) => Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .primaryNavy
                                                          .withValues(
                                                              alpha: 0.05),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .primaryNavy,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ))
                                              .toList()
                                            ..addAll([
                                              if (rev.tipAmount > 0)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.starGold
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.favorite,
                                                          size: 10,
                                                          color: Colors.red),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Tipped Rs ${rev.tipAmount}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.brown,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ]),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: AppColors.starGold, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${rev.rating}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
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
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.near_me_rounded, size: 20),
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dividerColor, width: 0.9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
