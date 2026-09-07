import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
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
    final workerProvider = Provider.of<WorkerProvider>(context);
    final worker = workerProvider.currentWorkerProfile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
            child: const Icon(
              Icons.engineering,
              size: 56,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            worker?.name ?? auth.userModel?.fullName ?? 'Worker',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            worker?.profession ?? 'General Skilled Worker',
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 24),

          // Actions List
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
                          content: Text('Contact support at worker-support@cyns.com')),
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
