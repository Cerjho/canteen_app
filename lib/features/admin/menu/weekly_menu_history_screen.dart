import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/interfaces/i_weekly_menu_service.dart';
import '../../../shared/components/loading_indicator.dart';

/// Weekly Menu History Screen - Browse and manage past published menus
class WeeklyMenuHistoryScreen extends ConsumerStatefulWidget {
  const WeeklyMenuHistoryScreen({super.key});

  @override
  ConsumerState<WeeklyMenuHistoryScreen> createState() => _WeeklyMenuHistoryScreenState();
}

class _WeeklyMenuHistoryScreenState extends ConsumerState<WeeklyMenuHistoryScreen> {
  int _limit = 10;
  String _statusFilter = 'all'; // all | draft | published | archived

  @override
  Widget build(BuildContext context) {
    final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
    
    // Watch dateRefreshProvider to ensure rebuild when date changes
    ref.watch(dateRefreshProvider);
    
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

          var menus = snapshot.data ?? [];
          // Apply status filter client-side
          if (_statusFilter != 'all') {
            menus = menus.where((m) => m.publishStatus == _statusFilter).toList();
          }

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

              // Status Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Draft'),
                      selected: _statusFilter == PublishStatus.draft,
                      onSelected: (_) => setState(() => _statusFilter = PublishStatus.draft),
                    ),
                    ChoiceChip(
                      label: const Text('Published'),
                      selected: _statusFilter == PublishStatus.published,
                      onSelected: (_) => setState(() => _statusFilter = PublishStatus.published),
                    ),
                    ChoiceChip(
                      label: const Text('Archived'),
                      selected: _statusFilter == PublishStatus.archived,
                      onSelected: (_) => setState(() => _statusFilter = PublishStatus.archived),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Filters + Menu List
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
    final weekDate = menu.weekStart;
    final weekRange = weeklyMenuService.getWeekDateRange(weekDate);
    final isCurrentWeek = _isCurrentWeek(weekDate);
    
    // Count total items and days with at least one item
    int totalItems = 0;
    int daysWithItems = 0;
    for (var dayMenu in menu.menuItemsByDay.values) {
      int dayCount = 0;
      for (var mealTypeItems in dayMenu.values) {
        final len = mealTypeItems.length;
        totalItems += len;
        dayCount += len;
      }
      if (dayCount > 0) daysWithItems++;
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
                const SizedBox(width: 8),
                // Status chip
                Chip(
                  label: Text(menu.publishStatus.substring(0, 1).toUpperCase() + menu.publishStatus.substring(1)),
                  backgroundColor: menu.publishStatus == PublishStatus.published
                      ? Colors.green.withValues(alpha: 0.1)
                      : (menu.publishStatus == PublishStatus.archived
                          ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
                          : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2)),
                  side: BorderSide(
                    color: menu.publishStatus == PublishStatus.published
                        ? Colors.green
                        : (menu.publishStatus == PublishStatus.archived
                            ? theme.colorScheme.outline
                            : theme.colorScheme.tertiary),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // Version chip when > 0
                if (menu.currentVersion > 0)
                  Chip(
                    label: Text('v${menu.currentVersion}'),
                    visualDensity: VisualDensity.compact,
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
                    const PopupMenuItem(
                      value: 'versions',
                      child: Row(
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 12),
                          Text('Versions'),
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
                    if (menu.publishStatus != PublishStatus.archived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined),
                            SizedBox(width: 12),
                            Text('Archive'),
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
                    label: '$daysWithItems Day${daysWithItems == 1 ? '' : 's'}',
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Menu info
            Text(
              menu.publishStatus == PublishStatus.published
                  ? 'Published menu'
                  : (menu.publishStatus == PublishStatus.archived ? 'Archived menu' : 'Draft menu'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
      case 'versions':
        await _showVersionsDialog(context, menu, weeklyMenuService);
        break;
      case 'copy':
        await _copyToCurrentWeek(context, menu, weeklyMenuService);
        break;
      case 'archive':
        await _archiveMenu(context, menu, weeklyMenuService);
        break;
    }
  }

  Future<void> _showVersionsDialog(
    BuildContext context,
    WeeklyMenu menu,
    IWeeklyMenuService weeklyMenuService,
  ) async {
    final versions = await weeklyMenuService.getWeeklyMenuVersions(menu.weekStart);
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Column(
            children: [
              ListTile(
                title: const Text('Versions'),
                subtitle: Text('Week of ${_formatWeekDate(menu.weekStart)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: versions.isEmpty
                    ? const Center(child: Text('No versions yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final v = versions[index];
                          final version = v['version'] as int;
                          final createdAt = DateTime.tryParse(v['created_at']?.toString() ?? '');
                          // created_by could be displayed if you add a user lookup
                          return ListTile(
                            leading: CircleAvatar(child: Text('v$version')),
                            title: Text('Version $version'),
                            subtitle: Text(createdAt != null ? createdAt.toLocal().toString() : ''),
                            trailing: OutlinedButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Revert to this version?'),
                                    content: Text('This will replace the current draft with contents of v$version. You can publish after reviewing changes.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revert')),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                await weeklyMenuService.revertToVersion(menu.weekStart, version);
                                if (context.mounted) {
                                  Navigator.pop(context); // close versions dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reverted. Menu is now Draft'), backgroundColor: Colors.orange),
                                  );
                                }
                              },
                              child: const Text('Revert'),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: versions.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveMenu(
    BuildContext context,
    WeeklyMenu menu,
    IWeeklyMenuService weeklyMenuService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Menu'),
        content: Text('Archive menu for week of ${_formatWeekDate(menu.weekStart)}? You can unarchive later by editing and publishing again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirm != true) return;
    await weeklyMenuService.archiveWeeklyMenu(menu.weekStart);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archived'), backgroundColor: Colors.grey),
      );
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
                        'Week of ${_formatWeekDate(menu.weekStart)}',
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

                    // Enforce stable weekday order and hide completely empty days
                    const orderedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

                    List<Widget> dayCards = [];
                    for (final day in orderedDays) {
                      final mealTypes = menu.menuItemsByDay[day] ?? const <String, List<String>>{};

                      // Compute total items for the day across meals
                      final totalForDay = ['breakfast', 'lunch', 'snack', 'drinks']
                          .map((k) => mealTypes[k]?.length ?? 0)
                          .fold<int>(0, (a, b) => a + b);

                      if (totalForDay == 0) {
                        // Skip empty days to reduce noise in history view
                        continue;
                      }

                      dayCards.add(
                        _buildDayDetails(
                          day,
                          mealTypes,
                          itemMap,
                        ),
                      );
                    }

                    // If all days were empty, still show an informational card
                    if (dayCards.isEmpty) {
                      dayCards.add(
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No items scheduled for this week',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: dayCards,
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
    // Order meals and hide empty meal sections
    const mealOrder = ['breakfast', 'lunch', 'snack', 'drinks'];
    final orderedMeals = mealOrder
        .map((k) => MapEntry(k, List<String>.from(mealTypes[k] ?? const <String>[])))
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (orderedMeals.isEmpty) return const SizedBox.shrink();

    // Count items for header chip
    final totalForDay = orderedMeals.fold<int>(0, (a, e) => a + e.value.length);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$totalForDay item${totalForDay == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...orderedMeals.map((mealTypeEntry) {
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
          'Copy this menu from ${_formatWeekDate(menu.weekStart)} to the current week?\n\n'
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
        menuByDay: menu.menuItemsByDay,
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

  String _formatWeekDate(DateTime weekStartDate) {
    final date = weekStartDate;
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }
}
