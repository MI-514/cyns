import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/location_service.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/worker_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import 'request_waiting_countdown_screen.dart';
import 'worker_profile_view_screen.dart';
import '../../core/widgets/worker_badge_widget.dart';

class WorkerListScreen extends StatefulWidget {
  final String selectedCategoryId;
  final String categoryName;
  final String? searchQuery;

  const WorkerListScreen({
    super.key,
    required this.selectedCategoryId,
    required this.categoryName,
    this.searchQuery,
  });

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  late TextEditingController _searchController;
  bool _isAutoDispatching = false;

  Future<void> _dispatchWorker(WorkerProfileModel targetWorker) async {
    if (_isAutoDispatching) return;
    final location = Provider.of<LocationProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);

    setState(() => _isAutoDispatching = true);

    try {
      final double cLat = location.currentPosition?.latitude ?? 31.5204;
      final double cLng = location.currentPosition?.longitude ?? 74.3587;
      final String cAddress = location.currentAddress.isNotEmpty
          ? location.currentAddress
          : 'Customer Current Location';

      ServiceRequestModel req = ServiceRequestModel(
        id: '',
        customerId: auth.userModel?.uid ?? 'c1',
        customerName: auth.userModel?.fullName ?? 'Customer',
        customerPhone: auth.userModel?.phoneNumber ?? '',
        workerId: targetWorker.workerId,
        workerName: targetWorker.name,
        workerPhone: targetWorker.phoneNumber,
        categoryId: widget.selectedCategoryId,
        categoryName: widget.categoryName,
        problemDescription:
            'Direct Location Dispatch for ${widget.categoryName}',
        customerLat: cLat,
        customerLng: cLng,
        customerAddress: cAddress,
        workerLat: targetWorker.latitude ?? cLat,
        workerLng: targetWorker.longitude ?? cLng,
        status: AppConstants.statusPending,
      );

      String? reqId = await requestProvider.createRequest(req);

      if (!mounted) return;
      setState(() => _isAutoDispatching = false);

      if (reqId != null) {
        ServiceRequestModel createdReq = ServiceRequestModel(
          id: reqId,
          customerId: req.customerId,
          customerName: req.customerName,
          customerPhone: req.customerPhone,
          workerId: req.workerId,
          workerName: req.workerName,
          workerPhone: req.workerPhone,
          categoryId: req.categoryId,
          categoryName: req.categoryName,
          problemDescription: req.problemDescription,
          customerLat: req.customerLat,
          customerLng: req.customerLng,
          customerAddress: req.customerAddress,
          workerLat: req.workerLat,
          workerLng: req.workerLng,
          status: req.status,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestWaitingCountdownScreen(
              request: createdReq,
              attemptedWorkerIds: [targetWorker.workerId],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(requestProvider.errorMessage.isNotEmpty
                ? requestProvider.errorMessage
                : 'Failed to dispatch request.'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAutoDispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dispatching worker: $e'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    }
  }

  Future<void> _autoDispatchNearestWorker() async {
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    if (workerProvider.searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No active ${widget.categoryName} technicians found nearby.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
      return;
    }
    await _dispatchWorker(workerProvider.searchResults.first);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWorkersOnly();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchWorkersOnly() async {
    final loc = Provider.of<LocationProvider>(context, listen: false);
    await loc.fetchCurrentLocation(context: context);

    if (!mounted) return;

    Provider.of<WorkerProvider>(context, listen: false).searchWorkers(
      categoryId: widget.selectedCategoryId,
      customerLat: loc.currentPosition?.latitude,
      customerLng: loc.currentPosition?.longitude,
      query: _searchController.text,
    );
  }

  Widget _buildWorkerLocationBanner(BuildContext context,
      WorkerProfileModel worker, double? dist, bool hasValidGps) {
    String distanceText = (hasValidGps && dist != null)
        ? LocationService.formatDistance(dist)
        : "GPS OFF (Tap to enable)";
    String etaText =
        (hasValidGps && dist != null) ? LocationService.calculateETA(dist) : "";

    return GestureDetector(
      onTap: () {
        if (!hasValidGps) {
          LocationService.promptEnableGps(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryNavy.withValues(alpha: 0.08),
              AppColors.accentBlue.withValues(alpha: 0.06),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryNavy.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasValidGps
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                size: 16,
                color: AppColors.pureWhite,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        distanceText.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (etaText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.availableGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⚡ ~$etaText ETA',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.availableGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (worker.workingArea.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🏡 Area: ${worker.workingArea}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workerProvider = Provider.of<WorkerProvider>(context);
    final location = Provider.of<LocationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Center Location Radar Search Card
            _LocationRadarWidget(
              categoryName: widget.categoryName,
              address: location.currentAddress,
              isSearching: workerProvider.isLoading,
              isGpsDisabled: location.isGpsDisabled,
              onSearch: _fetchWorkersOnly,
              onCancel: () {
                Navigator.pop(context);
              },
            ),

            // GPS Disabled Warning Banner
            if (location.isGpsDisabled || location.currentPosition == null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.statusPending),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_rounded,
                        color: AppColors.statusPending, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'GPS is turned off. Distances cannot be calculated accurately.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      child: const Text('Turn On GPS',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Search Bar Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Filter workers by name or skill...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.primaryNavy),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _fetchWorkersOnly,
                  ),
                ),
                onSubmitted: (_) => _fetchWorkersOnly(),
              ),
            ),
            const SizedBox(height: 18),

            // Nearby Workers Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nearby Available ${widget.categoryName}s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.availableGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${workerProvider.searchResults.length} Found',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.availableGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Instant Auto-Dispatch Button (Direct 1-Tap Search & Dispatch)
            if (workerProvider.searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isAutoDispatching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.bolt, size: 24),
                    label: Text(
                      _isAutoDispatching
                          ? 'Dispatching Nearest Worker...'
                          : 'Instant Auto-Dispatch',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    onPressed:
                        _isAutoDispatching ? null : _autoDispatchNearestWorker,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            // Workers List
            workerProvider.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )
                : workerProvider.searchResults.isEmpty
                    ? Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.dividerColor),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 52, color: AppColors.textLight),
                            const SizedBox(height: 10),
                            Text(
                              'No available workers found for "${widget.categoryName}".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: workerProvider.searchResults.length,
                        itemBuilder: (context, index) {
                          final worker = workerProvider.searchResults[index];
                          double dist = 0.0;
                          bool hasValidGps = location.currentPosition != null &&
                              worker.latitude != null &&
                              worker.longitude != null;

                          if (hasValidGps) {
                            dist = location.calculateDistance(
                                worker.latitude!, worker.longitude!);
                          }

                          return Card(
                            elevation: 3,
                            shadowColor: const Color(0x0C0F172A),
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                  color: AppColors.dividerColor, width: 1.0),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WorkerProfileViewScreen(
                                      workerId: worker.workerId,
                                      worker: worker,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppColors.primaryNavy
                                              .withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.primaryNavy,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      worker.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 17,
                                                        color: AppColors
                                                            .primaryNavy,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .availableGreen
                                                          .withValues(
                                                              alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Text(
                                                      'Available',
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .availableGreen,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${worker.profession} • ${worker.experienceYears} yrs exp',
                                                style: const TextStyle(
                                                  color: AppColors.accentBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              WorkerBadgeRow(
                                                worker: worker,
                                                compact: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Prominent Location & Distance Banner
                                    _buildWorkerLocationBanner(
                                        context, worker, dist, hasValidGps),

                                    if (worker.serviceDescription.isNotEmpty)
                                      Text(
                                        worker.serviceDescription,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            size: 18,
                                            color: AppColors.starGold),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${worker.rating} (${worker.reviewCount})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(Icons.work_history_rounded,
                                            size: 15,
                                            color: AppColors.textLight),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${worker.completedJobsCount} jobs',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primaryNavy,
                                            side: const BorderSide(
                                                color: AppColors.primaryNavy),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    WorkerProfileViewScreen(
                                                  workerId: worker.workerId,
                                                  worker: worker,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Profile',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryNavy,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                              Icons.near_me_rounded,
                                              size: 13),
                                          label: const Text(
                                            'Hire',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () =>
                                              _dispatchWorker(worker),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LocationRadarWidget extends StatefulWidget {
  final String categoryName;
  final String address;
  final bool isSearching;
  final bool isGpsDisabled;
  final VoidCallback onSearch;
  final VoidCallback onCancel;

  const _LocationRadarWidget({
    required this.categoryName,
    required this.address,
    required this.isSearching,
    required this.isGpsDisabled,
    required this.onSearch,
    required this.onCancel,
  });

  @override
  State<_LocationRadarWidget> createState() => _LocationRadarWidgetState();
}

class _LocationRadarWidgetState extends State<_LocationRadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LOCATION-BASED WORKER SEARCH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accentBlue,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.categoryName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 20),

          // Center Location Radar Animation
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Pulsing Circle 3
                  Container(
                    width: 160 + (_animationController.value * 24),
                    height: 160 + (_animationController.value * 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryNavy.withValues(
                          alpha: 0.06 * (1 - _animationController.value)),
                    ),
                  ),
                  // Ring Circle 2
                  Container(
                    width: 125,
                    height: 125,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.accentBlue.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Ring Circle 1
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryNavy.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppColors.primaryNavy.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                  // Center Location Icon Button
                  GestureDetector(
                    onTap: () {
                      if (widget.isGpsDisabled) {
                        LocationService.promptEnableGps(context);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isGpsDisabled
                            ? AppColors.statusPending
                            : AppColors.primaryNavy,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isGpsDisabled
                            ? Icons.location_off_rounded
                            : Icons.location_on_rounded,
                        color: AppColors.pureWhite,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isGpsDisabled
                    ? Icons.location_off_rounded
                    : Icons.my_location_rounded,
                size: 16,
                color: widget.isGpsDisabled
                    ? AppColors.statusPending
                    : AppColors.accentBlue,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isGpsDisabled
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: widget.isGpsDisabled
                        ? AppColors.statusPending
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Control Buttons: Cancel & Search
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusRejected,
                    side: const BorderSide(
                        color: AppColors.statusRejected, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel'),
                  onPressed: widget.onCancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: widget.isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.near_me_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isSearching ? 'Searching...' : 'Search',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  onPressed: widget.isSearching ? null : widget.onSearch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
