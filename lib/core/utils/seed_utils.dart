import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';
import '../providers/app_providers.dart';
import 'seed_data_util.dart';
import 'seed_analytics_data.dart';

/// Centralized utility class for all seeding operations
class SeedUtils {
  /// Seed base data (students, parents, menu items)
  static Future<void> seedDatabase(BuildContext context) async {
    try {
      final seedData = SeedDataUtil();
      await seedData.seedAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Database seeded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error seeding database: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  /// Seed test orders for analytics
  static Future<void> seedTestOrders({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    // Get menu items first
    final menuItemsAsync = ref.read(menuItemsProvider);
    final menuItems = menuItemsAsync.value ?? [];

    if (menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add menu items first before seeding orders.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm before seeding
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Test Orders?'),
        content: const Text(
          'This will:\n'
          '• Delete ALL existing orders\n'
          '• Create ~130 test orders for current week\n'
          '• Use real students from database\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Seed Orders'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌱 Seeding test orders... This may take a moment.'),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Seed the orders
      final seedUtil = SeedAnalyticsData(FirebaseFirestore.instance);
      await seedUtil.seedOrdersForCurrentWeek(menuItems);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test orders seeded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error seeding orders: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }

  /// Seed test orders (non-ref version for non-Consumer widgets)
  static Future<void> seedTestOrdersWithMenuItems({
    required BuildContext context,
    required List<MenuItem> menuItems,
  }) async {
    if (menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add menu items first before seeding orders.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm before seeding
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Test Orders?'),
        content: const Text(
          'This will:\n'
          '• Delete ALL existing orders\n'
          '• Create ~130 test orders for current week\n'
          '• Use real students from database\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Seed Orders'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌱 Seeding test orders... This may take a moment.'),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Seed the orders
      final seedUtil = SeedAnalyticsData(FirebaseFirestore.instance);
      await seedUtil.seedOrdersForCurrentWeek(menuItems);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test orders seeded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error seeding orders: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
  }
}
