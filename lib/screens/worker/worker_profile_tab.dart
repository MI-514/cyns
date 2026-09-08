import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../auth/role_selection_screen.dart';
import '../shared/settings_screen.dart';
import 'edit_worker_profile_screen.dart';

class WorkerProfileTab extends StatelessWidget {
  const WorkerProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;
    final workerProvider = Provider.of<WorkerProvider>(context);
    final worker = workerProvider.currentWorkerProfile;

    String displayPic = worker?.profilePicUrl ?? user?.profilePicUrl ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Profile Picture / Avatar
          Center(
            child: displayPic.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: AppNetworkImage(
                      imageUrl: displayPic,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  )
                : CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        AppColors.primaryNavy.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.engineering,
                      size: 56,
                      color: AppColors.primaryNavy,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          Text(
            worker?.name.isNotEmpty == true
                ? worker!.name
                : user?.fullName ?? 'Worker Name',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),

          // Username Tag
          if (worker?.username.isNotEmpty == true ||
              user?.username.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '@${worker?.username.isNotEmpty == true ? worker!.username : user?.username}',
                style: const TextStyle(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          Text(
            worker?.profession.isNotEmpty == true
                ? worker!.profession
                : 'General Skilled Worker',
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),

          // Registration Form Main Data Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Worker Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const Divider(height: 20),

                  _WorkerDetailRow(
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    value: worker?.name.isNotEmpty == true
                        ? worker!.name
                        : user?.fullName ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Father Name',
                    value: worker?.fatherName.isNotEmpty == true
                        ? worker!.fatherName
                        : 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.alternate_email,
                    label: 'Unique Username',
                    value: worker?.username.isNotEmpty == true
                        ? '@${worker!.username}'
                        : user?.username.isNotEmpty == true
                            ? '@${user!.username}'
                            : 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.work_outline,
                    label: 'Main Skill',
                    value: worker?.profession ?? 'N/A',
                  ),
                  _WorkerDetailRow(
                    icon: Icons.history_edu,
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
                  _WorkerDetailRow(
                    icon: Icons.star_rate_rounded,
                    label: 'Rating & Performance',
                    value:
                        '${worker?.rating ?? 5.0} ⭐ (${worker?.reviewCount ?? 0} Reviews) | ${worker?.completedJobsCount ?? 0} Jobs Completed',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Professional Profile'),
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
          const SizedBox(height: 20),

          // Actions List Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined,
                      color: AppColors.primaryNavy),
                  title: const Text('App Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline,
                      color: AppColors.primaryNavy),
                  title: const Text('Help & Worker Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Contact support at worker-support@cyns.com')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.statusRejected),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                        color: AppColors.statusRejected,
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
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
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.08),
            child: Icon(icon, size: 20, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
