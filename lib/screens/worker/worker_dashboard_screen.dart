import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/notification_center_screen.dart';
import 'active_job_screen.dart';
import 'worker_home_tab.dart';
import 'worker_job_history_tab.dart';
import 'worker_profile_tab.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userModel != null) {
        Provider.of<WorkerProvider>(context, listen: false)
            .fetchWorkerProfile(auth.userModel!.uid);
      }
    });
  }

  final List<Widget> _tabs = const [
    WorkerHomeTab(),
    ActiveJobScreen(),
    WorkerJobHistoryTab(),
    WorkerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.engineering,
                size: 20,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'CYN Worker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen()),
              );
            },
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          } else {
            bool? shouldExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Are you sure you want to exit CYN Worker?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
            if (shouldExit == true && context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox_rounded),
            label: 'New Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline_rounded),
            activeIcon: Icon(Icons.play_circle_fill_rounded),
            label: 'Active Job',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            activeIcon: Icon(Icons.task_alt_rounded),
            label: 'Done Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
