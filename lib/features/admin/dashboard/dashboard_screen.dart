import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:convert';
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

  // Small provider used to trigger manual refreshes of token claims in the
  // debug panel. Incrementing the value forces the widget to rebuild and
  // re-run the FutureBuilder that fetches token claims.
  static final _debugClaimsRefreshProvider = StateProvider<int>((ref) => 0);

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

                // Dev-only debug panel: shows current user UID and token claims.
                // Visible only in debug builds (kDebugMode).
                _buildDebugPanel(context, ref),

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
  /// Dev-only debug panel that displays current user UID and token claims.
  /// Visible only when `kDebugMode` is true.
  Widget _buildDebugPanel(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;
  // watch the refresh counter so pressing refresh will rebuild the
  // FutureBuilder below and fetch fresh claims.
  final refreshCounter = ref.watch(DashboardScreen._debugClaimsRefreshProvider);

    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug (dev only)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText('UID: ${user?.id ?? 'not signed in'}'),
            const SizedBox(height: 8),
            FutureBuilder(
              key: ValueKey(refreshCounter),
              // Force refresh to ensure session is current in debug mode.
              // Depend on `refreshCounter` so the FutureBuilder is rebuilt when
              // the refresh button is pressed.
              future: user != null ? supabase.auth.refreshSession() : Future.value(null),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Loading session...');
                }
                if (snapshot.hasError) {
                  return Text('Error loading session: ${snapshot.error}');
                }
                final userMetadata = user?.userMetadata ?? <String, dynamic>{};
                final appMetadata = user?.appMetadata ?? <String, dynamic>{};
                final allData = {
                  'user_metadata': userMetadata,
                  'app_metadata': appMetadata,
                };
                final pretty = const JsonEncoder.withIndent('  ').convert(allData);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('User metadata:'),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Refresh metadata',
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                // increment the refresh counter to force rebuild
                                ref.read(DashboardScreen._debugClaimsRefreshProvider.notifier).state++;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Refreshing claims...')),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Copy UID',
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                final messenger = ScaffoldMessenger.of(context);
                                Clipboard.setData(ClipboardData(text: user?.id ?? '')).then((_) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('UID copied to clipboard')),
                                  );
                                });
                              },
                            ),
                            IconButton(
                              tooltip: 'Copy metadata',
                              icon: const Icon(Icons.file_copy),
                              onPressed: () {
                                final messenger = ScaffoldMessenger.of(context);
                                Clipboard.setData(ClipboardData(text: pretty)).then((_) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Metadata copied to clipboard')),
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: SelectableText(pretty),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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
