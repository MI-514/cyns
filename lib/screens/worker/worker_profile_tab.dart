import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../auth/role_selection_screen.dart';
import '../shared/settings_screen.dart';
import 'edit_worker_profile_screen.dart';
import '../../core/widgets/worker_badge_widget.dart';

class WorkerProfileTab extends StatelessWidget {
  const WorkerProfileTab({super.key});

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.statusRejected),
            SizedBox(width: 10),
            Text('Confirm Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content:
            const Text('Are you sure you want to sign out from CYN Worker?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;
    final workerProvider = Provider.of<WorkerProvider>(context);
    final worker = workerProvider.currentWorkerProfile;

    String displayPic = worker?.profilePicUrl ?? user?.profilePicUrl ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Hero Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryNavy, AppColors.lightNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.pureWhite,
                        shape: BoxShape.circle,
                      ),
                      child: displayPic.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(44),
                              child: AppNetworkImage(
                                imageUrl: displayPic,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CircleAvatar(
                              radius: 44,
                              backgroundColor:
                                  AppColors.primaryNavy.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.engineering_rounded,
                                size: 48,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.availableGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      worker?.name.isNotEmpty == true
                          ? worker!.name
                          : user?.fullName ?? 'Worker Name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.pureWhite,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        color: AppColors.accentBlue, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  worker?.profession.isNotEmpty == true
                      ? worker!.profession
                      : 'General Skilled Worker',
                  style: const TextStyle(
                    color: AppColors.starGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (worker?.username.isNotEmpty == true ||
                    user?.username.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '@${worker?.username.isNotEmpty == true ? worker!.username : user?.username}',
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (worker != null) ...[
                  const SizedBox(height: 12),
                  WorkerBadgeRow(worker: worker),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Worker Performance Stats Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.starGold, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '${worker?.rating ?? 5.0} ★',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy),
                      ),
                      Text(
                        '${worker?.reviewCount ?? 0} Reviews',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.task_alt_rounded,
                          color: AppColors.availableGreen, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '${worker?.completedJobsCount ?? 0}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy),
                      ),
                      const Text(
                        'Jobs Completed',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.work_history_rounded,
                          color: AppColors.accentBlue, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        '${worker?.experienceYears ?? 1} Yrs',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryNavy),
                      ),
                      const Text(
                        'Experience',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Registration Form Main Data Card
          Card(
            elevation: 3,
            shadowColor: const Color(0x0C0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.dividerColor, width: 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.engineering_rounded,
                          color: AppColors.primaryNavy),
                      SizedBox(width: 10),
                      Text(
                        'Service Provider Profile Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _WorkerDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: worker?.name.isNotEmpty == true
                        ? worker!.name
                        : user?.fullName ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.badge_outlined,
                    label: "Father Name",
                    value: worker?.fatherName.isNotEmpty == true
                        ? worker!.fatherName
                        : 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Username',
                    value: worker?.username.isNotEmpty == true
                        ? '@${worker!.username}'
                        : user?.username.isNotEmpty == true
                            ? '@${user!.username}'
                            : 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Main Skill',
                    value: worker?.profession ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.history_edu_rounded,
                    label: 'Experience',
                    value: '${worker?.experienceYears ?? 1} Years',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Mobile Number',
                    value: worker?.phoneNumber.isNotEmpty == true
                        ? worker!.phoneNumber
                        : user?.phoneNumber ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    value: user?.email ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Current Address',
                    value: worker?.address.isNotEmpty == true
                        ? worker!.address
                        : worker?.workingArea ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.credit_card_outlined,
                    label: 'CNIC Number',
                    value: worker?.cnicNumber.isNotEmpty == true
                        ? worker!.cnicNumber
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side:
                    const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              label: const Text('Edit Professional Profile',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditWorkerProfileScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Actions List Card
          Card(
            elevation: 3,
            shadowColor: const Color(0x0C0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.dividerColor, width: 1.0),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_outlined,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('App Settings',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('Help & Worker Support',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Contact support at worker-support@cyns.com')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusRejected.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColors.statusRejected),
                  ),
                  title: const Text(
                    'Logout Account',
                    style: TextStyle(
                        color: AppColors.statusRejected,
                        fontWeight: FontWeight.w800),
                  ),
                  onTap: () => _showLogoutDialog(context, auth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _WorkerDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WorkerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}