import 'package:flutter/material.dart';
import '../../core/models/menu_item.dart';
import '../../core/models/weekly_menu_analytics.dart';

/// Analytics utility functions and helpers
class AnalyticsUtils {
  /// Get color for category with distinct Material 3 colors
  static Color getCategoryColor(String? category, ColorScheme colorScheme) {
    switch (category?.toLowerCase()) {
      case 'drinks':
        return Colors.green;
      case 'snack':
        return Colors.blue;
      case 'lunch':
        return Colors.orange;
      default:
        return colorScheme.tertiary;
    }
  }

  /// Get all unique categories from menu items
  static List<String> getCategories(List<MenuItem> menuItems) {
    final categories = menuItems.map((item) => item.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Get gradient color based on trend (decline to rise)
  static Color getTrendColor(double changePercent) {
    if (changePercent < -10) return Colors.red;
    if (changePercent < 0) return Colors.orange;
    if (changePercent < 10) return Colors.yellow.shade700;
    return Colors.green;
  }

  /// Get category distribution from analytics
  static Map<String, int> getCategoryDistribution(
    WeeklyMenuAnalytics analytics,
    List<MenuItem> menuItems,
  ) {
    final Map<String, int> distribution = {};
    final itemMap = {for (var item in menuItems) item.id: item};

    for (var entry in analytics.totalOrderCounts.entries) {
      final item = itemMap[entry.key];
      if (item != null) {
        distribution[item.category] = (distribution[item.category] ?? 0) + entry.value;
      }
    }

    return distribution;
  }

  /// Get top N items for a specific day
  static List<MapEntry<String, int>> getTopItemsForDay(
    String day,
    int n,
    WeeklyMenuAnalytics analytics,
  ) {
    final dayOrders = analytics.orderCountsByDay[day] ?? {};
    final sorted = dayOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Format date range label
  static String formatDateRange(DateTime start, DateTime end) {
    final startMonth = _getMonthName(start.month);
    final endMonth = _getMonthName(end.month);
    
    if (start.month == end.month) {
      return '$startMonth ${start.day}-${end.day}, ${start.year}';
    } else {
      return '$startMonth ${start.day} - $endMonth ${end.day}, ${start.year}';
    }
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Calculate week-over-week change percentage
  static double calculateChangePercent(int current, int previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  /// Generate accessibility summary for analytics
  static String generateAnalyticsSummary(WeeklyMenuAnalytics analytics) {
    return 'Weekly analytics showing ${analytics.totalOrders} total orders. '
           'Average of ${analytics.averageOrdersPerDay.toStringAsFixed(1)} orders per day.';
  }
}

/// Drill-down modal for detailed item analytics
class DrillDownModal extends StatelessWidget {
  final String title;
  final Widget content;
  final bool isLoading;

  const DrillDownModal({
    super.key,
    required this.title,
    required this.content,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: (isMobile 
                        ? theme.textTheme.titleMedium 
                        : theme.textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : content,
            ),
          ],
        ),
      ),
    );
  }
}

/// Item drill-down content showing daily breakdown
class ItemDrillDownContent extends StatelessWidget {
  final String itemId;
  final String itemName;
  final WeeklyMenuAnalytics analytics;

  const ItemDrillDownContent({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    // Get daily breakdown for this item
    final dailyOrders = <String, int>{};
    for (var day in weekdays) {
      final dayOrders = analytics.orderCountsByDay[day] ?? {};
      dailyOrders[day] = dayOrders[itemId] ?? 0;
    }

    final totalOrders = dailyOrders.values.fold(0, (sum, count) => sum + count);

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        // Summary Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Text(
                  itemName,
                  style: (isMobile 
                    ? theme.textTheme.titleMedium 
                    : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $totalOrders orders this week',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Daily Breakdown
        Text(
          'Daily Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...weekdays.map((day) {
          final orders = dailyOrders[day] ?? 0;
          final percentage = totalOrders > 0 ? (orders / totalOrders * 100) : 0.0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  day.substring(0, 1),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: orders > 0
                  ? Text('${percentage.toStringAsFixed(1)}% of weekly orders')
                  : const Text('No orders'),
              trailing: Text(
                '$orders',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Day drill-down content showing top items for that day
class DayDrillDownContent extends StatelessWidget {
  final String day;
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const DayDrillDownContent({
    super.key,
    required this.day,
    required this.analytics,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    final topItems = AnalyticsUtils.getTopItemsForDay(day, 3, analytics);
    final itemMap = {for (var item in menuItems) item.id: item};
    final totalDayOrders = analytics.getOrdersForDay(day);

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      children: [
        // Summary Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Text(
                  day,
                  style: (isMobile 
                    ? theme.textTheme.titleMedium 
                    : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $totalDayOrders orders',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Top Items
        Text(
          'Top 3 Items',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (topItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No orders for this day',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          )
        else
          ...topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final itemEntry = entry.value;
            final item = itemMap[itemEntry.key];
            final orders = itemEntry.value;
            final percentage = totalDayOrders > 0 
                ? (orders / totalDayOrders * 100) 
                : 0.0;

            final medalEmoji = index == 0 ? '🥇' : (index == 1 ? '🥈' : '🥉');

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AnalyticsUtils.getCategoryColor(
                    item?.category,
                    theme.colorScheme,
                  ),
                  child: Text(
                    medalEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  item?.name ?? 'Unknown Item',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(item?.category ?? 'Unknown'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        AnalyticsUtils.getCategoryColor(
                          item?.category,
                          theme.colorScheme,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$orders',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Category legend widget
class CategoryLegend extends StatelessWidget {
  final List<MenuItem> menuItems;
  final WeeklyMenuAnalytics? analytics;

  const CategoryLegend({
    super.key,
    required this.menuItems,
    this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = AnalyticsUtils.getCategories(menuItems);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Wrap(
      spacing: isMobile ? 6 : 8,
      runSpacing: isMobile ? 6 : 8,
      alignment: WrapAlignment.center,
      children: categories.map((category) {
        final color = AnalyticsUtils.getCategoryColor(category, theme.colorScheme);
        
        return Chip(
          avatar: CircleAvatar(
            backgroundColor: color,
            radius: isMobile ? 8 : 10,
          ),
          label: Text(
            category,
            style: TextStyle(fontSize: isMobile ? 11 : 12),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
