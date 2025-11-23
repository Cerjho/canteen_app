import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
          // Build a small dataset for the mini chart. If you have a proper
          // provider for weekly revenue, replace this with that provider.
          final List<double> weeklyRevenue = List.generate(7, (i) {
            // create small variation around average
            final base = (stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
            final factor = 0.6 + (i / 10);
            return (base / 7) * factor;
          });

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Stats + Mini Chart
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 900;
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats grid
                            Expanded(
                              flex: 3,
                              child: Wrap(
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
                            ),

                            const SizedBox(width: 16),

                            // Mini chart + quick actions
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Revenue (last 7 days)',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            height: 120,
                                            child: MiniLineChart(data: weeklyRevenue),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Avg: ${FormatUtils.currency((weeklyRevenue.reduce((a, b) => a + b) / weeklyRevenue.length))}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Quick Actions',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.add),
                                                label: const Text('Add Menu Item'),
                                                onPressed: () => context.go('/menu/new'),
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.person_add),
                                                label: const Text('New Student'),
                                                onPressed: () => context.go('/students/new'),
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.payments),
                                                label: const Text('Top-ups'),
                                                onPressed: () => context.go('/topups'),
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.analytics),
                                                label: const Text('Reports'),
                                                onPressed: () => context.go('/reports'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
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
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Revenue (last 7 days)',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 140,
                                      child: MiniLineChart(data: weeklyRevenue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Actions',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Menu Item'),
                                          onPressed: () => context.go('/menu/new'),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.person_add),
                                          label: const Text('New Student'),
                                          onPressed: () => context.go('/students/new'),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.payments),
                                          label: const Text('Top-ups'),
                                          onPressed: () => context.go('/topups'),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.analytics),
                                          label: const Text('Reports'),
                                          onPressed: () => context.go('/reports'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                }),

                const SizedBox(height: 24),

                // Recent Orders
                Text(
                  'Today\'s Orders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
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
                          // TODO: Fetch student name from students table using order.studentId
                          final studentInitial = '#'; // Placeholder
                          final studentDisplay = 'Student ${order.studentId.substring(0, 6)}...'; // Placeholder
                          
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(studentInitial),
                            ),
                            title: Text(studentDisplay),
                            subtitle: Text(
                              '${order.items.length} items • ${FormatUtils.time(order.deliveryDate)}',
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

/// Simple mini line chart built with CustomPaint to avoid new dependencies.
class MiniLineChart extends StatelessWidget {
  final List<double> data;

  const MiniLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniLineChartPainter(data),
      size: Size.infinite,
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  final List<double> data;

  _MiniLineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final paintFill = Paint()
      // withOpacity is deprecated in some Flutter versions; use withAlpha to
      // avoid deprecation warnings and precision loss.
      ..color = Colors.blueAccent.withAlpha(31)
      ..style = PaintingStyle.fill;

    if (data.isEmpty) return;

    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final range = (max - min) == 0 ? 1 : (max - min);

    final stepX = size.width / (data.length - 1).clamp(1, data.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * size.height;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // fill under line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
