import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../customer/customer_dashboard_screen.dart';
import '../worker/worker_dashboard_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isAuthenticated && auth.userModel != null) {
      String role = auth.userModel!.role;
      if (role == AppConstants.roleWorker) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WorkerDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Icon(
                Icons.handyman,
                size: 64,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CYN',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppColors.pureWhite,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppConstants.appTagline,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.pureWhite),
            ),
          ],
        ),
      ),
    );
  }
}
