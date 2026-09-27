import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
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
                    child: const Icon(Icons.palette_outlined,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('App Theme',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Navy Blue & Modern White Palette'),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Active',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('Push Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Live Job & Status Updates'),
                  trailing: Switch(
                    value: true,
                    activeTrackColor: AppColors.primaryNavy,
                    activeThumbColor: AppColors.pureWhite,
                    onChanged: (val) {},
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('Location Services',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('High Precision Doorstep GPS'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('About CYN App',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Version 1.0.0+1 (Chase Your Needs)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: AppColors.primaryNavy),
                  ),
                  title: const Text('Privacy Policy & Safety',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'CYN respects user privacy and data security.')),
                    );
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
