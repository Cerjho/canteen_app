import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/config/theme_mode_provider.dart';
import '../student_link/student_link_screen.dart';

/// Settings Screen - Profile and app settings
/// 
/// Features:
/// - Show parent profile info (name, contact, email)
/// - Manage linked children (add/remove)
/// - Notification preferences
/// - App settings
/// - Logout
class SettingsScreen extends ConsumerWidget {
  void _toggleThemeMode(WidgetRef ref, bool isDark) {
    ref.read(themeModeProvider.notifier).state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final currentUser = ref.watch(currentUserProvider);
  final currentParent = ref.watch(currentParentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: currentUser.when(
        data: (user) {
          return ListView(
            children: [
              // Profile section with parent photo
              _buildProfileSection(context, ref, user, currentParent),
              const Divider(),
              // Linked children section
              _buildLinkedChildrenSection(context),
              const Divider(),
              // Preferences section
              _buildPreferencesSection(context),
              const Divider(),
              // About section
              _buildAboutSection(context),
              const Divider(),
              // Logout button
              _buildLogoutSection(context, ref),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  /// Build profile section
  Widget _buildProfileSection(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    AsyncValue<dynamic> parentAsync,
  ) {
    // Get parent photo URL if available
    final parent = parentAsync.value;
    final photoUrl = parent?.photoUrl;

    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40.r,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            onBackgroundImageError: photoUrl != null
                ? (exception, stackTrace) {
                    // Handle image load error silently
                    // Falls back to showing the icon below
                  }
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: 40.sp,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          SizedBox(height: 16.h),
          Text(
            user?.name ?? 'Parent User',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 4.h),
          Text(
            user?.email ?? 'No email',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          SizedBox(height: 16.h),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile coming soon')),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  /// Build linked children section
  Widget _buildLinkedChildrenSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Linked Children',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentLinkScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Link New Student',
              ),
            ],
          ),
        ),
        ListTile(
          leading: const CircleAvatar(child: Text('J')),
          title: const Text('Juan Dela Cruz'),
          subtitle: const Text('Grade 5 • Student ID: 12345'),
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Student details coming soon')),
              );
            },
          ),
        ),
        ListTile(
          leading: const CircleAvatar(child: Text('M')),
          title: const Text('Maria Dela Cruz'),
          subtitle: const Text('Grade 3 • Student ID: 12346'),
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Student details coming soon')),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build preferences section
  Widget _buildPreferencesSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final themeMode = ref.watch(themeModeProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                'Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SwitchListTile(
              secondary: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark Mode'),
              subtitle: Text(themeMode == ThemeMode.dark ? 'Dark theme enabled' : 'Light theme enabled'),
              value: themeMode == ThemeMode.dark,
              onChanged: (val) => _toggleThemeMode(ref, val),
              activeThumbColor: theme.colorScheme.primary,
              inactiveThumbColor: theme.colorScheme.secondary,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive order updates and reminders'),
              value: true,
              onChanged: (value) {
                // TODO: Implement notification toggle
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.email_outlined),
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive weekly summary emails'),
              value: false,
              onChanged: (value) {
                // TODO: Implement email notification toggle
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.warning_outlined),
              title: const Text('Low Balance Alerts'),
              subtitle: const Text('Alert when balance is below ₦100'),
              value: true,
              onChanged: (value) {
                // TODO: Implement low balance alert toggle
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Language selection coming soon')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Build about section
  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outlined),
          title: const Text('App Version'),
          subtitle: const Text('1.0.0'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Terms of Service coming soon')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy Policy coming soon')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & Support'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & Support coming soon')),
            );
          },
        ),
      ],
    );
  }

  /// Build logout section
  Widget _buildLogoutSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Loheca Canteen Parent App',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          Text(
            '© 2025 All rights reserved',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.pop(context);
                // TODO: Navigate to login screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
