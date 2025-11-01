import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/interfaces/i_weekly_menu_service.dart';
import '../../../shared/components/loading_indicator.dart';
import '../../../core/providers/date_refresh_provider.dart';

/// Weekly Menu History Screen - Browse and manage past published menus
class WeeklyMenuHistoryScreen extends ConsumerStatefulWidget {
  const WeeklyMenuHistoryScreen({super.key});

  @override
  ConsumerState<WeeklyMenuHistoryScreen> createState() => _WeeklyMenuHistoryScreenState();
}

class _WeeklyMenuHistoryScreenState extends ConsumerState<WeeklyMenuHistoryScreen> {
  int _limit = 10;

  @override
  Widget build(BuildContext context) {
    final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Menu History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: StreamBuilder<List<WeeklyMenu>>(
        stream: weeklyMenuService.streamWeeklyMenuHistory(limit: _limit),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(text: 'Loading history...');
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final menus = snapshot.data ?? [];

          if (menus.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Published Menus',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Published weekly menus will appear here'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Instructions
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'View past published menus or copy them to the current week',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),

              // Menu List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: menus.length + 1,
                  itemBuilder: (context, index) {
                    if (index == menus.length) {
                      // Load More button
                      if (menus.length >= _limit) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _limit += 10;
                                });
                              },
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load More'),
                            ),
                          ),
                        );
                      }
                      return const SizedBox(height: 80);
                    }

                    final menu = menus[index];
                    return _buildMenuCard(context, menu, weeklyMenuService);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    WeeklyMenu menu,
    IWeeklyMenuService weeklyMenuService,
  ) {
    final theme = Theme.of(context);
    final weekDate = DateTime.parse(menu.weekStartDate);
    final weekRange = weeklyMenuService.getWeekDateRange(weekDate);
    final isCurrentWeek = _isCurrentWeek(weekDate);
    
    // Count total items
    int totalItems = 0;
    for (var dayMenu in menu.menuByDay.values) {
      for (var mealTypeItems in dayMenu.values) {
        totalItems += mealTypeItems.length;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Week badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrentWeek
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isCurrentWeek
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        weekRange,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCurrentWeek
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentWeek) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Current'),
                    backgroundColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => _handleAction(context, value, menu, weeklyMenuService),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility),
                          SizedBox(width: 12),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (!isCurrentWeek)
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy),
                            SizedBox(width: 12),
                            Text('Copy to This Week'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Menu details
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.restaurant_menu,
                    label: '$totalItems Items',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.calendar_view_week,
                    label: '${menu.menuByDay.length} Days',
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Published info
            Text(
              menu.publishedAt != null 
                  ? 'Published ${_formatDateTime(menu.publishedAt!)}'
                  : 'Draft (Not Published)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            // Copied from info
            if (menu.copiedFromWeek != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.content_copy,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Copied from ${_formatWeekDate(menu.copiedFromWeek!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    WeeklyMenu menu,
    IWeeklyMenuService weeklyMenuService,
  ) async {
    switch (action) {
      case 'view':
        await _showMenuDetails(context, menu);
        break;
      case 'copy':
        await _copyToCurrentWeek(context, menu, weeklyMenuService);
        break;
    }
  }

  Future<void> _showMenuDetails(BuildContext context, WeeklyMenu menu) async {
    final menuItemsAsync = ref.read(menuItemsProvider);
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Week of ${_formatWeekDate(menu.weekStartDate)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Menu details
              Expanded(
                child: menuItemsAsync.when(
                  data: (menuItems) {
                    final itemMap = {for (var item in menuItems) item.id: item};
                    
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: menu.menuByDay.entries.map((dayEntry) {
                        return _buildDayDetails(
                          dayEntry.key,
                          dayEntry.value,
                          itemMap,
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayDetails(
    String day,
    Map<String, List<String>> mealTypes,
    Map<String, MenuItem> itemMap,
  ) {
    if (mealTypes.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...mealTypes.entries.map((mealTypeEntry) {
              final mealType = mealTypeEntry.key;
              final itemIds = mealTypeEntry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${MealType.icons[mealType] ?? ''} ${MealType.displayNames[mealType] ?? mealType}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...itemIds.map((itemId) {
                      final item = itemMap[itemId];
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Text(
                          '• ${item?.name ?? 'Unknown Item'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToCurrentWeek(
    BuildContext context,
    WeeklyMenu menu,
    IWeeklyMenuService weeklyMenuService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy to Current Week'),
        content: Text(
          'Copy this menu from ${_formatWeekDate(menu.weekStartDate)} to the current week?\n\n'
          'This will replace any existing menu for the current week.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final currentWeek = ref.read(dateRefreshProvider);
      await weeklyMenuService.publishWeeklyMenu(
        weekStartDate: currentWeek,
        menuByDay: menu.menuByDay,
        copiedFromWeek: menu.weekStartDate,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu copied to current week successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying menu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isCurrentWeek(DateTime weekDate) {
    final now = ref.watch(dateRefreshProvider);
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekDate = DateTime(
      currentWeekStart.year,
      currentWeekStart.month,
      currentWeekStart.day,
    );
    final compareDate = DateTime(weekDate.year, weekDate.month, weekDate.day);
    return compareDate.isAtSameMomentAs(currentWeekDate);
  }

  String _formatWeekDate(String weekStartDate) {
    final date = DateTime.parse(weekStartDate);
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = ref.watch(dateRefreshProvider);
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'on ${_formatWeekDate(dateTime.toIso8601String().substring(0, 10))}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
