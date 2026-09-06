import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Registered Users'),
      ),
      body: admin.allUsers.isEmpty
          ? const Center(child: Text('No registered users found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.allUsers.length,
              itemBuilder: (context, index) {
                final user = admin.allUsers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == 'customer'
                          ? AppColors.primaryNavy.withOpacity(0.1)
                          : AppColors.accentBlue.withOpacity(0.1),
                      child: Icon(
                        user.role == 'customer'
                            ? Icons.person
                            : Icons.engineering,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    title: Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${user.email} • ${user.phoneNumber}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
