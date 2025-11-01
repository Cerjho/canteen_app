import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/weekly_menu_analytics.dart';
import '../../core/models/menu_item.dart';
import 'analytics_utils.dart';

/// Top Items Bar Chart - Shows most ordered items with drill-down interactivity
class TopItemsChart extends StatelessWidget {
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const TopItemsChart({
    super.key,
    required this.analytics,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topItems = analytics.getTopItems(5);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (topItems.isEmpty) {
      return _buildEmptyState(context, 'No order data available');
    }

    // Create a map for quick item lookup
    final itemMap = {for (var item in menuItems) item.id: item};
    
    return Semantics(
      label: AnalyticsUtils.generateAnalyticsSummary(analytics),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Top 5 Most Ordered Items',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          // Category Legend
          CategoryLegend(menuItems: menuItems, analytics: analytics),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: topItems.first.value.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                      final index = barTouchResponse!.spot!.touchedBarGroupIndex;
                      final itemId = topItems[index].key;
                      final item = itemMap[itemId];
                      
                      if (item != null) {
                        // Show drill-down modal
                        showDialog(
                          context: context,
                          builder: (context) => DrillDownModal(
                            title: 'Item Analytics',
                            content: ItemDrillDownContent(
                              itemId: itemId,
                              itemName: item.name,
                              analytics: analytics,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final itemId = topItems[groupIndex].key;
                      final item = itemMap[itemId];
                      return BarTooltipItem(
                        '${item?.name ?? 'Unknown'}\n',
                        TextStyle(
                          color: theme.colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} orders\nTap for details',
                            style: TextStyle(
                              color: theme.colorScheme.inversePrimary.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 50 : 60,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= topItems.length) {
                          return const SizedBox.shrink();
                        }
                        final itemId = topItems[value.toInt()].key;
                        final item = itemMap[itemId];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            item?.name ?? 'Unknown',
                            style: TextStyle(fontSize: isMobile ? 9 : 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 32 : 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  topItems.length,
                  (index) {
                    final itemId = topItems[index].key;
                    final item = itemMap[itemId];
                    final color = AnalyticsUtils.getCategoryColor(
                      item?.category,
                      theme.colorScheme,
                    );
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: topItems[index].value.toDouble(),
                          color: color,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Orders Per Day Bar Chart with drill-down to top items
class OrdersPerDayChart extends StatelessWidget {
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const OrdersPerDayChart({
    super.key,
    required this.analytics,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    
    final dayOrders = weekdays.map((day) {
      return analytics.getOrdersForDay(day);
    }).toList();
    
    final maxOrders = dayOrders.isEmpty ? 100 : dayOrders.reduce((a, b) => a > b ? a : b);
    
    if (maxOrders == 0) {
      return _buildEmptyState(context, 'No orders this week');
    }

    return Semantics(
      label: 'Orders by day chart. ${AnalyticsUtils.generateAnalyticsSummary(analytics)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Orders per Day',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxOrders.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                      final index = barTouchResponse!.spot!.touchedBarGroupIndex;
                      final day = weekdays[index];
                      
                      // Show drill-down modal
                      showDialog(
                        context: context,
                        builder: (context) => DrillDownModal(
                          title: '$day Analytics',
                          content: DayDrillDownContent(
                            day: day,
                            analytics: analytics,
                            menuItems: menuItems,
                          ),
                        ),
                      );
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${weekdays[groupIndex]}\n',
                        TextStyle(
                          color: theme.colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} orders\nTap for details',
                            style: TextStyle(
                              color: theme.colorScheme.inversePrimary.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= weekdays.length) {
                          return const SizedBox.shrink();
                        }
                        final day = weekdays[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            day.substring(0, 3),
                            style: TextStyle(fontSize: isMobile ? 10 : 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 32 : 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  weekdays.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: dayOrders[index].toDouble(),
                        color: theme.colorScheme.secondary,
                        width: 30,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Weekly Trend Line Chart - Compares last 4 weeks with gradient based on trend
class WeeklyTrendChart extends StatelessWidget {
  final List<WeeklyMenuAnalytics> weeklyAnalytics;

  const WeeklyTrendChart({
    super.key,
    required this.weeklyAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    if (weeklyAnalytics.isEmpty) {
      return _buildEmptyState(context, 'No historical data available');
    }

    // Sort by week (oldest first for the chart)
    final sortedAnalytics = List<WeeklyMenuAnalytics>.from(weeklyAnalytics)
      ..sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));

    final maxOrders = sortedAnalytics
        .map((a) => a.totalOrders)
        .reduce((a, b) => a > b ? a : b);

    // Calculate overall trend
    double trendPercent = 0.0;
    if (sortedAnalytics.length >= 2) {
      final first = sortedAnalytics.first.totalOrders;
      final last = sortedAnalytics.last.totalOrders;
      trendPercent = AnalyticsUtils.calculateChangePercent(last, first);
    }
    final trendColor = AnalyticsUtils.getTrendColor(trendPercent);

    return Semantics(
      label: 'Weekly trend showing ${sortedAnalytics.length} weeks of data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weekly Trend (Last ${sortedAnalytics.length} Weeks)',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (sortedAnalytics.length >= 2) ...[
            SizedBox(height: isMobile ? 4 : 6),
            Row(
              children: [
                Icon(
                  trendPercent >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: trendColor,
                  size: isMobile ? 16 : 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}% overall',
                  style: TextStyle(
                    color: trendColor,
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxOrders.toDouble() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      sortedAnalytics.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        sortedAnalytics[index].totalOrders.toDouble(),
                      ),
                    ),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow.shade700,
                        Colors.green,
                      ],
                      stops: const [0.0, 0.33, 0.66, 1.0],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        // Calculate color based on week-over-week change
                        Color dotColor = theme.colorScheme.primary;
                        if (index > 0) {
                          final current = sortedAnalytics[index].totalOrders;
                          final previous = sortedAnalytics[index - 1].totalOrders;
                          final change = AnalyticsUtils.calculateChangePercent(current, previous);
                          dotColor = AnalyticsUtils.getTrendColor(change);
                        }
                        
                        return FlDotCirclePainter(
                          radius: 6,
                          color: dotColor,
                          strokeWidth: 2,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.1),
                          Colors.orange.withValues(alpha: 0.1),
                          Colors.yellow.shade700.withValues(alpha: 0.1),
                          Colors.green.withValues(alpha: 0.1),
                        ],
                        stops: const [0.0, 0.33, 0.66, 1.0],
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedAnalytics.length) {
                          return const SizedBox.shrink();
                        }
                        final weekStart = sortedAnalytics[value.toInt()].weekStartDate;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _formatWeekLabel(weekStart),
                            style: TextStyle(fontSize: isMobile ? 9 : 11),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 32 : 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => theme.colorScheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final weekStart = sortedAnalytics[spot.x.toInt()].weekStartDate;
                        final orders = spot.y.toInt();
                        
                        // Calculate week-over-week change
                        String changeText = '';
                        if (spot.x.toInt() > 0) {
                          final previous = sortedAnalytics[spot.x.toInt() - 1].totalOrders;
                          final change = AnalyticsUtils.calculateChangePercent(orders, previous);
                          changeText = '\n${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs prev';
                        }
                        
                        return LineTooltipItem(
                          'Week ${_formatWeekLabel(weekStart)}\n',
                          TextStyle(
                            color: theme.colorScheme.inversePrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '$orders orders$changeText',
                              style: TextStyle(
                                color: theme.colorScheme.inversePrimary.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekLabel(String weekStartDate) {
    final date = DateTime.parse(weekStartDate);
    return '${date.month}/${date.day}';
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Category Distribution Pie Chart
class CategoryPieChart extends StatefulWidget {
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const CategoryPieChart({
    super.key,
    required this.analytics,
    required this.menuItems,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Get category distribution
    final distribution = AnalyticsUtils.getCategoryDistribution(
      widget.analytics,
      widget.menuItems,
    );

    if (distribution.isEmpty) {
      return _buildEmptyState(context, 'No category data available');
    }

    // Sort by count and take top 5 + other
    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = sortedEntries.take(5).toList();
    final otherCount = sortedEntries.skip(5).fold(0, (sum, e) => sum + e.value);
    
    final displayData = [...top5];
    if (otherCount > 0) {
      displayData.add(MapEntry('Other', otherCount));
    }

    final totalOrders = displayData.fold(0, (sum, e) => sum + e.value);

    return Semantics(
      label: 'Category distribution pie chart showing $totalOrders orders across ${displayData.length} categories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Orders by Category',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: isMobile ? 1 : 2,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = null;
                              return;
                            }
                            touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: isMobile ? 30 : 40,
                      sections: List.generate(displayData.length, (index) {
                        final entry = displayData[index];
                        final isTouched = index == touchedIndex;
                        final double radius = isTouched 
                            ? (isMobile ? 55 : 65) 
                            : (isMobile ? 45 : 55);
                        final double fontSize = isTouched 
                            ? (isMobile ? 14 : 16) 
                            : (isMobile ? 11 : 13);

                        final percentage = (entry.value / totalOrders * 100);
                        final color = entry.key == 'Other'
                            ? theme.colorScheme.outline
                            : AnalyticsUtils.getCategoryColor(entry.key, theme.colorScheme);

                        return PieChartSectionData(
                          color: color,
                          value: entry.value.toDouble(),
                          title: '${percentage.toStringAsFixed(0)}%',
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black26, blurRadius: 2),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                // Legend
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: displayData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final color = data.key == 'Other'
                          ? theme.colorScheme.outline
                          : AnalyticsUtils.getCategoryColor(data.key, theme.colorScheme);
                      final percentage = (data.value / totalOrders * 100);

                      return Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
                        child: Row(
                          children: [
                            Container(
                              width: isMobile ? 12 : 16,
                              height: isMobile ? 12 : 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: touchedIndex == index
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.key,
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 13,
                                      fontWeight: touchedIndex == index
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${data.value} (${percentage.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontSize: isMobile ? 10 : 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Categorical Top Items Chart - Shows top items grouped by category with stacked bars
class CategoricalTopItemsChart extends StatelessWidget {
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const CategoricalTopItemsChart({
    super.key,
    required this.analytics,
    required this.menuItems,
  });

  Color _getCategoryColor(String category, ColorScheme colorScheme) {
    switch (category.toLowerCase()) {
      case 'drinks':
        return Colors.green.shade600;
      case 'snack':
      case 'snacks':
        return Colors.orange.shade600;
      case 'lunch':
        return Colors.blue.shade600;
      default:
        return colorScheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Get top 3 items per category
    final topByCategory = analytics.getTopByCategory(3, menuItems);
    
    if (topByCategory.isEmpty) {
      return _buildEmptyState(context, 'No order data available');
    }

    // Create item map for quick lookup
    final itemMap = {for (var item in menuItems) item.id: item};

    // Sort categories for consistent display
    final categories = topByCategory.keys.toList()..sort();

    return Semantics(
      label: 'Top items by category. ${categories.length} categories shown.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Top 3 Items by Category',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          // Category Legend
          Wrap(
            spacing: isMobile ? 6 : 8,
            runSpacing: isMobile ? 6 : 8,
            alignment: WrapAlignment.center,
            children: categories.map((category) {
              final color = _getCategoryColor(category, theme.colorScheme);
              final total = analytics.getTotalForCategory(category, menuItems);
              
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: color,
                  radius: isMobile ? 8 : 10,
                ),
                label: Text(
                  '$category ($total)',
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(topByCategory),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final category = categories[groupIndex];
                      final items = topByCategory[category]!;
                      final item = itemMap[items[rodIndex].key];
                      final orders = items[rodIndex].value;
                      final categoryTotal = analytics.getTotalForCategory(category, menuItems);
                      final percentage = categoryTotal > 0 
                          ? (orders / categoryTotal * 100) 
                          : 0.0;

                      return BarTooltipItem(
                        '${item?.name ?? 'Unknown'}\n',
                        TextStyle(
                          color: theme.colorScheme.inversePrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$orders orders\n${percentage.toStringAsFixed(1)}% of $category',
                            style: TextStyle(
                              color: theme.colorScheme.inversePrimary.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 40 : 50,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= categories.length) {
                          return const SizedBox.shrink();
                        }
                        final category = categories[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 32 : 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  categories.length,
                  (index) {
                    final category = categories[index];
                    final items = topByCategory[category]!;
                    final baseColor = _getCategoryColor(category, theme.colorScheme);

                    // Create stacked bars (bottom to top)
                    final rods = <BarChartRodStackItem>[];
                    double fromY = 0;

                    for (int i = 0; i < items.length; i++) {
                      final toY = fromY + items[i].value.toDouble();
                      rods.add(
                        BarChartRodStackItem(
                          fromY,
                          toY,
                          // Vary shade for each item in stack
                          Color.lerp(
                            baseColor,
                            baseColor.withValues(alpha: 0.5),
                            i / items.length,
                          )!,
                        ),
                      );
                      fromY = toY;
                    }

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: fromY, // Total height
                          rodStackItems: rods,
                          width: isMobile ? 35 : 45,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY(Map<String, List<MapEntry<String, int>>> topByCategory) {
    double max = 0;
    for (var items in topByCategory.values) {
      final total = items.fold(0.0, (sum, e) => sum + e.value);
      if (total > max) max = total;
    }
    return max * 1.2;
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Categorical Orders Per Day Chart - Shows daily orders with category breakdown in tooltips
class CategoricalOrdersPerDayChart extends StatelessWidget {
  final WeeklyMenuAnalytics analytics;
  final List<MenuItem> menuItems;

  const CategoricalOrdersPerDayChart({
    super.key,
    required this.analytics,
    required this.menuItems,
  });

  Color _getCategoryColor(String category, ColorScheme colorScheme) {
    switch (category.toLowerCase()) {
      case 'drinks':
        return Colors.green.shade600;
      case 'snack':
      case 'snacks':
        return Colors.orange.shade600;
      case 'lunch':
        return Colors.blue.shade600;
      default:
        return colorScheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    
    final dayOrders = weekdays.map((day) {
      return analytics.getOrdersForDay(day);
    }).toList();
    
    final maxOrders = dayOrders.isEmpty ? 100 : dayOrders.reduce((a, b) => a > b ? a : b);
    
    if (maxOrders == 0) {
      return _buildEmptyState(context, 'No orders this week');
    }

    return Semantics(
      label: 'Orders by day with category breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Orders per Day (by Category)',
                  style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxOrders.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                    tooltipPadding: const EdgeInsets.all(10),
                    tooltipMargin: 8,
                    maxContentWidth: isMobile ? 180 : 220,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = weekdays[groupIndex];
                      final topByCategory = analytics.getTop3ForDayByCategory(day, menuItems);
                      
                      // Build tooltip with category breakdown
                      final buffer = StringBuffer();
                      buffer.writeln(day);
                      buffer.writeln('${rod.toY.toInt()} orders\n');

                      // Show top items by category
                      for (var category in topByCategory.keys) {
                        final items = topByCategory[category]!;
                        if (items.isNotEmpty) {
                          final topItem = items.first;
                          buffer.writeln('$category:');
                          buffer.write('  ${topItem.itemName} ${topItem.orders}');
                          buffer.write(' (${topItem.percentageOfDay.toStringAsFixed(0)}%)');
                          if (category != topByCategory.keys.last) {
                            buffer.writeln();
                          }
                        }
                      }

                      return BarTooltipItem(
                        buffer.toString(),
                        TextStyle(
                          color: theme.colorScheme.inversePrimary,
                          fontSize: isMobile ? 10 : 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= weekdays.length) {
                          return const SizedBox.shrink();
                        }
                        final day = weekdays[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            day.substring(0, 3),
                            style: TextStyle(fontSize: isMobile ? 10 : 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 32 : 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: isMobile ? 10 : 12),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  weekdays.length,
                  (index) {
                    final day = weekdays[index];
                    final dominantCategory = analytics.getDominantCategoryForDay(day, menuItems);
                    final color = dominantCategory != null
                        ? _getCategoryColor(dominantCategory, theme.colorScheme)
                        : theme.colorScheme.secondary;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: dayOrders[index].toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
