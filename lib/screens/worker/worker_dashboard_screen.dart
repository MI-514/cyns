import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../shared/notification_center_screen.dart';
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
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      _initializeWorkerData();
    }
  }

  Future<void> _initializeWorkerData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wp = Provider.of<WorkerProvider>(context, listen: false);
    
    String? uid = auth.userModel?.uid;
    
    if (uid == null) {
      uid = FirebaseAuth.instance.currentUser?.uid;
    }
    
    if (uid == null) {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('saved_user_id');
    }

    if (uid != null && uid.isNotEmpty) {
      wp.fetchWorkerProfile(uid);
      wp.listenToWorkerProfile(uid);
    }
  }

  final List<Widget> _tabs = const [
    WorkerHomeTab(),
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
      body: Consumer<WorkerProvider>(
        builder: (context, wp, child) {
          if (wp.isLoading && wp.currentWorkerProfile == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile data...'),
                ],
              ),
            );
          }
          return IndexedStack(
            index: _currentIndex,
            children: _tabs,
          );
        }
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'New Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
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