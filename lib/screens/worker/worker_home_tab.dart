import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/chat_screen.dart';
import '../shared/map_tracking_screen.dart';
import '../../core/services/audio_alert_service.dart';
import 'edit_worker_profile_screen.dart';

class WorkerHomeTab extends StatefulWidget {
  const WorkerHomeTab({super.key});

  @override
  State<WorkerHomeTab> createState() => _WorkerHomeTabState();
}

class _WorkerHomeTabState extends State<WorkerHomeTab> {
  String? _acceptingJobId;
  final Set<String> _notifiedPendingJobIds = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptJob(
    ServiceRequestModel req,
    ServiceRequestProvider requestProvider,
    WorkerProvider workerProvider,
  ) async {
    if (_acceptingJobId != null) return;

    setState(() => _acceptingJobId = req.id);

    try {
      // Silence alarm if it was ringing
      AudioAlertService.stopAlarmAlert();

      final currentWorker = workerProvider.currentWorkerProfile;
      final effectiveWorkerId =
          (currentWorker != null && currentWorker.workerId.isNotEmpty)
              ? currentWorker.workerId
              : req.workerId;
      final effectiveWorkerName =
          (currentWorker != null && currentWorker.name.isNotEmpty)
              ? currentWorker.name
              : req.workerName;
      final effectiveWorkerPhone =
          (currentWorker != null && currentWorker.phoneNumber.isNotEmpty)
              ? currentWorker.phoneNumber
              : req.workerPhone;

      // 1. Update status to Accepted (which also sets worker assignment in Firestore)
      await requestProvider.updateStatus(
        requestId: req.id,
        status: AppConstants.statusAccepted,
        customerId: req.customerId,
        workerId: effectiveWorkerId,
        workerName: effectiveWorkerName,
        workerPhone: effectiveWorkerPhone,
      );

      // 2. Mark worker offline in DB so next customers cannot hire them while busy
      if (effectiveWorkerId.isNotEmpty) {
        workerProvider.toggleAvailability(effectiveWorkerId, false).catchError((_) {});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Job accepted! Opening chat with customer...',
          ),
          backgroundColor: AppColors.statusCompleted,
          duration: Duration(seconds: 1),
        ),
      );

      // 3. Smooth, direct, and guaranteed navigation to Chat with customer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            requestId: req.id,
            peerName: req.customerName,
            peerRole: 'customer',
            peerId: req.customerId,
            peerPhone: req.customerPhone,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept job: $e'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _acceptingJobId = null);
      }
    }
  }

  void _showEnterCompletionOtpDialog(ServiceRequestModel req) async {
    final reqProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    final workerProvider =
        Provider.of<WorkerProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final expectedOtp = await reqProvider.ensureCompletionOtp(
      req.id,
      currentOtp: req.completionOtp,
    );

    if (!mounted) return;

    final codeController = TextEditingController();
    String enteredOtp = '';

    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.verified_user_rounded,
              size: 46, color: AppColors.statusCompleted),
          title: const Text(
            'Enter Verification Code',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ask the customer for the 4-digit Cross-Verification code shown on their screen to complete this job.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  color: AppColors.primaryNavy,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0000',
                  hintStyle: TextStyle(
                    letterSpacing: 10,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.statusCompleted, width: 2),
                  ),
                ),
                onChanged: (v) => enteredOtp = v.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusCompleted,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (enteredOtp.trim() == expectedOtp.trim()) {
                  Navigator.pop(dCtx, true);
                } else {
                  ScaffoldMessenger.of(dCtx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Incorrect code! Please verify the 4-digit code with customer.',
                      ),
                      backgroundColor: AppColors.statusRejected,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text(
                'Verify & Done',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (verified == true) {
      await reqProvider.updateStatus(
        requestId: req.id,
        status: AppConstants.statusCompleted,
        customerId: req.customerId,
        workerId: req.workerId,
      );

      final profile = workerProvider.currentWorkerProfile;
      if (profile != null) {
        await workerProvider.toggleAvailability(profile.workerId, true);
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Job verified and successfully completed! 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.statusCompleted,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showIssueDetailsModal(BuildContext context, ServiceRequestModel req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customer Issue Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Customer: ${req.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Address: ${req.customerAddress}',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Problem Comment / Description:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dividerColor),
              ),
              child: Text(
                req.problemDescription.isNotEmpty
                    ? req.problemDescription
                    : 'No text comment provided.',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            if (req.attachmentUrl != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Attached Issue Photo:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  req.attachmentUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(
                          color: AppColors.statusRejected, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text(
                      'Cancel Request',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      final reqProvider = Provider.of<ServiceRequestProvider>(
                        context,
                        listen: false,
                      );
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          title: const Text('Cancel Request?'),
                          content: const Text(
                            'Are you sure you want to cancel / decline this service request? It will be offered to another available technician.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Keep Offer'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusRejected,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Yes, Cancel Request'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        AudioAlertService.stopAlarmAlert();
                        await reqProvider.updateStatus(
                          requestId: req.id,
                          status: AppConstants.statusRejected,
                          customerId: req.customerId,
                          workerId: req.workerId,
                        );
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Request cancelled / declined.'),
                            backgroundColor: AppColors.statusRejected,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusCompleted,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Accept & Chat',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _acceptJob(
                        req,
                        Provider.of<ServiceRequestProvider>(context,
                            listen: false),
                        Provider.of<WorkerProvider>(context, listen: false),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workerProvider = Provider.of<WorkerProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    final worker = workerProvider.currentWorkerProfile;

    if (worker == null) {
      if (workerProvider.isLoading) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading worker profile...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 64, color: AppColors.primaryNavy),
              const SizedBox(height: 16),
              const Text(
                'Worker Profile Incomplete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please set up your profile skills and working area to start receiving nearby customer requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Set Up Profile Now'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditWorkerProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: requestProvider.getWorkerRequests(
        worker.workerId,
        categoryId: worker.categoryIds.isNotEmpty
            ? worker.categoryIds.first
            : worker.profession,
        categoryIds: worker.categoryIds,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRequests = snapshot.data ?? [];
        final now = DateTime.now();

        // Active ongoing jobs (Accepted, On the Way, Arrived, In Progress, or Work Done Pending Confirmation)
        final activeJobs = allRequests.where((r) =>
            r.status == AppConstants.statusAccepted ||
            r.status == AppConstants.statusOnTheWay ||
            r.status == AppConstants.statusArrived ||
            r.status == AppConstants.statusInProgress ||
            r.status == 'Work Done Pending Confirmation').toList();

        // Filter pending requests: ONLY show fresh requests within timeout window matching worker's trade.
        // Auto-expire older requests in Firestore so they disappear and don't pile up!
        final List<ServiceRequestModel> pendingRequests = [];
        final String workerProfNorm = worker.profession
            .trim()
            .toLowerCase()
            .replaceAll('_', '')
            .replaceAll(' ', '');
        final List<String> workerCatsNorm = worker.categoryIds
            .map((c) =>
                c.trim().toLowerCase().replaceAll('_', '').replaceAll(' ', ''))
            .toList();

        for (var r in allRequests) {
          if (r.status == AppConstants.statusPending) {
            final String reqCatNorm = r.categoryId
                .trim()
                .toLowerCase()
                .replaceAll('_', '')
                .replaceAll(' ', '');
            final String reqCatNameNorm = r.categoryName
                .trim()
                .toLowerCase()
                .replaceAll('_', '')
                .replaceAll(' ', '');

            final bool categoryMatches = workerCatsNorm.contains(reqCatNorm) ||
                workerCatsNorm.contains(reqCatNameNorm) ||
                (workerProfNorm.isNotEmpty &&
                    (workerProfNorm == reqCatNorm ||
                        workerProfNorm == reqCatNameNorm ||
                        workerProfNorm.contains(reqCatNorm) ||
                        reqCatNorm.contains(workerProfNorm) ||
                        workerProfNorm.contains(reqCatNameNorm) ||
                        reqCatNameNorm.contains(workerProfNorm))) ||
                worker.skills.any((s) {
                  final sClean = s
                      .trim()
                      .toLowerCase()
                      .replaceAll('_', '')
                      .replaceAll(' ', '');
                  return sClean == reqCatNorm || sClean == reqCatNameNorm;
                });

            // Ensure request matches the worker's profession/trade and is for this worker or open
            if (categoryMatches &&
                (r.workerId == worker.workerId || r.workerId.isEmpty)) {
              final ageSec = now.difference(r.createdAt).inSeconds;
              if (ageSec > AppConstants.requestTimeoutSeconds) {
                requestProvider.updateStatus(
                  requestId: r.id,
                  status: AppConstants.statusMissed,
                  customerId: r.customerId,
                  workerId: r.workerId,
                );
              } else {
                pendingRequests.add(r);
              }
            }
          }
        }

        final bool hasActiveJob = activeJobs.isNotEmpty;
        final ServiceRequestModel? currentActiveJob =
            hasActiveJob ? activeJobs.first : null;

        // Play alert tone ONCE when a new pending job arrives and worker is available
        if (pendingRequests.isNotEmpty && !hasActiveJob && worker.isAvailable) {
          final newRequests = pendingRequests
              .where((r) => !_notifiedPendingJobIds.contains(r.id))
              .toList();
          if (newRequests.isNotEmpty) {
            for (var r in newRequests) {
              _notifiedPendingJobIds.add(r.id);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationService.playIncomingJobAlertBeep();
            });
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Availability Header Card with Gradient
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasActiveJob
                        ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                        : [AppColors.primaryNavy, AppColors.lightNavy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Hello, ${worker.name}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasActiveJob
                                      ? AppColors.starGold
                                      : (worker.isAvailable
                                          ? AppColors.availableGreen
                                          : AppColors.unavailableRed),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (hasActiveJob
                                              ? AppColors.starGold
                                              : (worker.isAvailable
                                                  ? AppColors.availableGreen
                                                  : AppColors.unavailableRed))
                                          .withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveJob
                                ? 'BUSY • Active Job in progress (Offline for other customers)'
                                : (worker.isAvailable
                                    ? 'ONLINE • Ready to receive nearby requests'
                                    : 'OFFLINE • Toggle switch to start receiving jobs'),
                            style: TextStyle(
                              color: hasActiveJob
                                  ? AppColors.starGold
                                  : AppColors.textLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.scale(
                      scale: 1.1,
                      child: Switch(
                        value: hasActiveJob ? false : worker.isAvailable,
                        activeTrackColor: AppColors.availableGreen,
                        activeThumbColor: AppColors.pureWhite,
                        onChanged: (val) {
                          if (hasActiveJob) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '🔒 Status is locked to OFFLINE while you have an active job. It will automatically reopen once the job is completed!',
                                ),
                                backgroundColor: AppColors.primaryNavy,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }
                          workerProvider.toggleAvailability(
                              worker.workerId, val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Worker Summary Stats Row
              Row(
                children: [
                  Expanded(
                    child: _WorkerSummaryTile(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.starGold,
                      title: 'Rating',
                      value: '${worker.rating} ★',
                      subtitle: '${worker.reviewCount} Reviews',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WorkerSummaryTile(
                      icon: Icons.check_circle_rounded,
                      iconColor: AppColors.availableGreen,
                      title: 'Jobs Done',
                      value: '${worker.completedJobsCount}',
                      subtitle: 'Completed',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WorkerSummaryTile(
                      icon: Icons.work_history_rounded,
                      iconColor: AppColors.accentBlue,
                      title: 'Experience',
                      value: '${worker.experienceYears} Yrs',
                      subtitle: worker.profession,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ACTIVE ONGOING JOB SECTION (Displayed prominently when busy)
              if (hasActiveJob && currentActiveJob != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.orange, size: 22),
                        SizedBox(width: 6),
                        Text(
                          'Ongoing Active Job',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusAccepted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.statusAccepted
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        currentActiveJob.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.statusAccepted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Card(
                  elevation: 4,
                  shadowColor: AppColors.primaryNavy.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: AppColors.accentBlue.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Offline notice banner
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.starGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.starGold.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_clock_rounded,
                                  color: Colors.orange, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '🔒 Offline for other customers until this job is finished.',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentActiveJob.categoryName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.statusAccepted
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                currentActiveJob.status,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.statusAccepted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primaryNavy
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.person,
                                  size: 16, color: AppColors.primaryNavy),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentActiveJob.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: AppColors.accentBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                currentActiveJob.customerAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons: Open Chat & Open Live Map
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline,
                                    size: 18),
                                label: const Text(
                                  'Open Chat',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        requestId: currentActiveJob.id,
                                        peerName: currentActiveJob.customerName,
                                        peerRole: 'customer',
                                        peerId: currentActiveJob.customerId,
                                        peerPhone:
                                            currentActiveJob.customerPhone,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accentBlue,
                                  side: const BorderSide(
                                      color: AppColors.accentBlue, width: 1.5),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.navigation_outlined,
                                    size: 18),
                                label: const Text(
                                  'Live Map',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapTrackingScreen(
                                          request: currentActiveJob),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (currentActiveJob.status ==
                                'Work Done Pending Confirmation' ||
                            currentActiveJob.status ==
                                AppConstants.statusInProgress) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusCompleted,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.verified_user_rounded,
                                  size: 18),
                              label: const Text(
                                'Enter 4-Digit Code to Complete Job',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () =>
                                  _showEnterCompletionOtpDialog(currentActiveJob),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusRejected,
                              side: const BorderSide(
                                  color: AppColors.statusRejected, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text(
                              'Cancel Request / Job',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: const Text('Cancel Ongoing Job?'),
                                  content: const Text(
                                    'Are you sure you want to cancel this job request? The customer will be informed and your profile will be set back to online.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Keep Job'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.statusRejected,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Yes, Cancel Job'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await requestProvider.updateStatus(
                                  requestId: currentActiveJob.id,
                                  status: AppConstants.statusCancelled,
                                  customerId: currentActiveJob.customerId,
                                  workerId: currentActiveJob.workerId,
                                );
                                await workerProvider.toggleAvailability(
                                    worker.workerId, true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Job cancelled. You are now back online.'),
                                      backgroundColor: AppColors.primaryNavy,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Incoming Service Requests Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Incoming Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE STREAM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // If worker is engaged in an active job, pause incoming offers
              if (hasActiveJob) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 46, color: Colors.orange),
                        SizedBox(height: 10),
                        Text(
                          'Job Queue Busy',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You are currently working on an active job. New incoming requests are paused so you can focus on finishing your current task.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (pendingRequests.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_rounded,
                            size: 52, color: AppColors.textLight),
                        const SizedBox(height: 10),
                        const Text(
                          'No new pending requests right now.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Stay online to receive instant doorstep job offers.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (worker.workerId.contains('guest')) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.bolt, size: 18),
                            label: const Text(
                              '⚡ Create Test Job Request',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final catId = worker.categoryIds.isNotEmpty
                                  ? worker.categoryIds.first
                                  : (worker.profession
                                          .toLowerCase()
                                          .contains('electric')
                                      ? 'electrician'
                                      : 'plumber');
                              final profName = worker.profession.isNotEmpty
                                  ? worker.profession
                                  : 'Technician';
                              final req = ServiceRequestModel(
                                id: 'req_test_${DateTime.now().millisecondsSinceEpoch}',
                                customerId: 'guest_customer_cyn',
                                customerName: 'Ali Raza (Guest Customer)',
                                customerPhone: '+923009876543',
                                workerId: worker.workerId,
                                workerName: worker.name,
                                workerPhone: worker.phoneNumber,
                                categoryId: catId,
                                categoryName: '$profName Service',
                                problemDescription:
                                    'Urgent: $profName issue needing immediate inspection.',
                                customerLat: 31.5204,
                                customerLng: 74.3587,
                                customerAddress:
                                    'House #42, Block B, Gulberg III, Lahore',
                                status: AppConstants.statusPending,
                              );
                              await requestProvider.createRequest(req);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final req = pendingRequests[index];
                    final bool isCurrentAccepting = _acceptingJobId == req.id;
                    final ageSec = now.difference(req.createdAt).inSeconds;
                    final remainingSec = (AppConstants.requestTimeoutSeconds - ageSec)
                        .clamp(0, AppConstants.requestTimeoutSeconds);

                    return Card(
                      elevation: 3,
                      shadowColor: const Color(0x0C0F172A),
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                            color: AppColors.dividerColor, width: 1.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Incoming Job Ringer Alert Banner with live countdown
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.starGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.starGold
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '🔔 INCOMING JOB OFFER! Respond within ${remainingSec}s',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  req.categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined,
                                          size: 13, color: Colors.red),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${remainingSec}s left',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primaryNavy
                                      .withValues(alpha: 0.1),
                                  child: const Icon(Icons.person,
                                      size: 16, color: AppColors.primaryNavy),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  req.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 16, color: AppColors.accentBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    req.customerAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // View Request Issue Details Modal Launcher
                            if (req.problemDescription.isNotEmpty ||
                                req.attachmentUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryNavy,
                                    side: const BorderSide(
                                        color: AppColors.primaryNavy,
                                        width: 1.2),
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                  icon: const Icon(Icons.find_in_page_rounded,
                                      size: 18),
                                  label: const Text(
                                    'View Request Issue Details (Photo & Comment)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    _showIssueDetailsModal(context, req);
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.statusRejected,
                                      side: const BorderSide(
                                          color: AppColors.statusRejected,
                                          width: 1.5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.cancel_outlined,
                                        size: 16),
                                    label: const Text(
                                      'Cancel Request',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    onPressed: isCurrentAccepting
                                        ? null
                                        : () async {
                                            bool? confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                title: const Text(
                                                    'Cancel Request?'),
                                                content: const Text(
                                                  'Are you sure you want to cancel / decline this service offer? It will be offered to another available technician.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text(
                                                        'Keep Offer'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: AppColors
                                                          .statusRejected,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text(
                                                        'Yes, Cancel Request'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              AudioAlertService
                                                  .stopAlarmAlert();
                                              await requestProvider
                                                  .updateStatus(
                                                requestId: req.id,
                                                status: AppConstants
                                                    .statusRejected,
                                                customerId: req.customerId,
                                                workerId: req.workerId,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Request cancelled / declined.'),
                                                    backgroundColor: AppColors
                                                        .statusRejected,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.statusCompleted,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    onPressed: isCurrentAccepting
                                        ? null
                                        : () => _acceptJob(
                                              req,
                                              requestProvider,
                                              workerProvider,
                                            ),
                                    child: isCurrentAccepting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Accept Job'),
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
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WorkerSummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _WorkerSummaryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
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
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
