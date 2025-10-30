import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/models/order.dart';
import '../../../shared/components/stat_card.dart';
import '../../../shared/components/loading_indicator.dart';

/// Dashboard Screen - shows overview and statistics
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysOrdersAsync = ref.watch(todaysOrdersProvider);
    final todayStatsAsync = ref.watch(todayStatsProvider);
    final pendingTopupsCountAsync = ref.watch(pendingTopupsCountProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(todaysOrdersProvider);
              ref.invalidate(todayStatsProvider);
              ref.invalidate(pendingTopupsCountProvider);
            },
          ),
        ],
      ),
      body: todayStatsAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    StatCard(
                      title: 'Today\'s Orders',
                      value: stats['totalOrders'].toString(),
                      icon: Icons.shopping_bag,
                      color: Colors.blue,
                    ),
                    StatCard(
                      title: 'Today\'s Revenue',
                      value: FormatUtils.currency(stats['totalRevenue']),
                      icon: Icons.currency_exchange,
                      color: Colors.green,
                    ),
                    StatCard(
                      title: 'Pending Orders',
                      value: stats['pendingOrders'].toString(),
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                    pendingTopupsCountAsync.when(
                      data: (count) => StatCard(
                        title: 'Pending Top-ups',
                        value: count.toString(),
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                      ),
                      loading: () => const StatCard(
                        title: 'Pending Top-ups',
                        value: '...',
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                      ),
                      error: (_, __) => const StatCard(
                        title: 'Pending Top-ups',
                        value: 'Error',
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Recent Orders
                Text(
                  'Today\'s Orders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                todaysOrdersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No orders today',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orders.length > 10 ? 10 : orders.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(order.studentName[0]),
                            ),
                            title: Text(order.studentName),
                            subtitle: Text(
                              '${order.items.length} items • ${FormatUtils.time(order.orderDate)}',
                            ),
                            trailing: Chip(
                              label: Text(order.status.displayName),
                              backgroundColor: _getStatusColor(order.status),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('Error: $error'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(
          child: Text('Error loading dashboard: $error'),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange[100]!;
      case OrderStatus.confirmed:
        return Colors.blue[100]!;
      case OrderStatus.preparing:
        return Colors.amber[100]!;
      case OrderStatus.ready:
        return Colors.green[100]!;
      case OrderStatus.completed:
        return Colors.grey[300]!;
      case OrderStatus.cancelled:
        return Colors.red[100]!;
    }
  }
}
