import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../worker/worker_dashboard_screen.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _loginGuest(BuildContext context, String role) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loginAsGuest(role: role);

    if (!context.mounted) return;

    if (role == AppConstants.roleWorker) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WorkerDashboardScreen()),
        (route) => false,
      );
    } else if (role == 'admin') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('CYN – Chase Your Needs'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Welcome to CYN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select how you want to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Customer / Employer Option Card
              _RoleCard(
                title: 'Customer / Employer',
                description:
                    'Find nearby plumbers, electricians, mechanics and hire skilled workers easily.',
                icon: Icons.person_search,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(
                          selectedRole: AppConstants.roleCustomer),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Worker / Service Provider Option Card
              _RoleCard(
                title: 'Worker / Service Provider',
                description:
                    'Offer your skills, manage availability, receive nearby service requests, and grow your work.',
                icon: Icons.engineering,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(
                          selectedRole: AppConstants.roleWorker),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Quick Guest Mode Section for Testing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Text(
                          '⚡ Quick Guest Test Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bypass email & password to test the app instantly:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: () => _loginGuest(context, AppConstants.roleCustomer),
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('Test as Guest Customer'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        side: const BorderSide(color: AppColors.primaryNavy),
                      ),
                      onPressed: () => _loginGuest(context, AppConstants.roleWorker),
                      icon: const Icon(Icons.engineering, size: 18),
                      label: const Text('Test as Guest Worker'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _loginGuest(context, 'admin'),
                      icon: const Icon(Icons.admin_panel_settings, size: 18, color: Colors.deepOrange),
                      label: const Text(
                        'Test as Guest Admin',
                        style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
