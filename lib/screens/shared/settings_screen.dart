import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.palette_outlined,
                      color: AppColors.primaryNavy),
                  title: Text('App Theme'),
                  subtitle: Text('Navy Blue & White Theme (Active)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_none,
                      color: AppColors.primaryNavy),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Enabled'),
                  trailing: Switch(
                    value: true,
                    activeTrackColor: AppColors.primaryNavy,
                    onChanged: (val) {},
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.location_on_outlined,
                      color: AppColors.primaryNavy),
                  title: Text('Location Services'),
                  subtitle: Text('High Accuracy'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline,
                      color: AppColors.primaryNavy),
                  title: Text('About CYN App'),
                  subtitle: Text('Version 1.0.0+1'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primaryNavy),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('CYN respects user privacy and security.')),
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
