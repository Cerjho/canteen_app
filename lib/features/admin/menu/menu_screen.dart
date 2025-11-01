import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/models/weekly_menu_analytics.dart';
import '../../../core/services/menu_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_download.dart' as file_download;
import '../../../core/utils/app_logger.dart';
import '../../../shared/components/loading_indicator.dart';
import '../../../shared/components/week_picker.dart';
import '../../../shared/components/analytics_charts.dart';
import 'menu_item_form_screen.dart';
import 'weekly_menu_history_screen.dart';
import '../../../core/providers/date_refresh_provider.dart';

/// Menu Management Screen with 3 distinct purposes:
/// - Tab 1 (All Menu Items): Master list for CRUD operations on food/drink items
/// - Tab 2 (Weekly Menu): Schedule management - assign items to specific days/meal-types
/// - Tab 3 (Analytics): View ordering statistics and trends
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  final bool _availableOnly = false;
  
  // Enhanced filtering and sorting state
  String _sortBy = 'name'; // 'name', 'price', 'popularity', 'updated'
  final Set<String> _selectedFilters = {}; // Advanced filters: 'available', 'unavailable', 'vegan', 'gf', 'price<30'
  RangeValues _priceRange = const RangeValues(0, 100);
  final Set<String> _bulkSelected = {}; // IDs of items selected for bulk actions
  
  // Weekly Menu State
  late TabController _tabController;
  late DateTime _selectedWeek; // Initialized in initState to Monday
  String _selectedDay = 'Monday';
  Map<String, Map<String, List<String>>> _currentMenuByDay = {};
  bool _isPublished = false;
  int _menuRefreshKey = 0; // Used to trigger FutureBuilder refresh
  
  // Analytics State
  late DateTime _analyticsWeek; // Initialized in initState to Monday
  bool _showCategorical = false; // Toggle for categorical view

  @override
  void initState() {
    super.initState();
  // Initialize both weeks to Monday of current week (critical for Firestore queries)
  // Use the centralized date provider so initialization is consistent and
  // won't capture a stale DateTime during hot-reload / resume.
  final now = ref.read(dateRefreshProvider);
  _selectedWeek = _getMondayOfWeek(now);
  _analyticsWeek = _getMondayOfWeek(now);
    
    _tabController = TabController(length: 3, vsync: this);
    
    // LOW PRIORITY - Polish: Smooth initial entry animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });

    // Rebuild when the calendar day changes so week selection and current-week
    // markers refresh automatically.
    ref.listenManual<DateTime?>(dateRefreshProvider, (previous, next) {
      if (mounted) {
        setState(() {
        // Advance selected weeks to current week if they were tracking 'today'
        final today = next;
        if (_selectedWeek.year == previous?.year && _selectedWeek.month == previous?.month && _selectedWeek.day == previous?.day) {
          _selectedWeek = _getMondayOfWeek(today!);
        }
        if (_analyticsWeek.year == previous?.year && _analyticsWeek.month == previous?.month && _analyticsWeek.day == previous?.day) {
          _analyticsWeek = _getMondayOfWeek(today!);
        }
      });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Get Monday of the week for a given date (critical for Firestore week alignment)
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Filter menu items based on advanced filters
  bool _matchesFilters(MenuItem item) {
    if (_selectedFilters.isEmpty) return true;
    
    for (final filter in _selectedFilters) {
      switch (filter) {
        case 'available':
          if (!item.isAvailable) return false;
          break;
        case 'unavailable':
          if (item.isAvailable) return false;
          break;
        case 'vegan':
          if (!item.isVegan) return false;
          break;
        case 'vegetarian':
          if (!item.isVegetarian) return false;
          break;
        case 'gf':
          if (!item.isGlutenFree) return false;
          break;
        case 'price<30':
          if (item.price >= 30) return false;
          break;
      }
    }
    
    // Price range filter
    if (item.price < _priceRange.start || item.price > _priceRange.end) {
      return false;
    }
    
    return true;
  }

  /// Sort menu items based on selected sort option
  List<MenuItem> _sortMenuItems(List<MenuItem> items) {
    final sortedList = List<MenuItem>.from(items);
    
    switch (_sortBy) {
      case 'name':
        sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'price':
        sortedList.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'updated':
        sortedList.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt;
          final bDate = b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate); // Most recent first
        });
        break;
      case 'popularity':
        // For now, sort by name as fallback (popularity would need analytics integration)
        // TODO: Integrate with WeeklyMenuAnalytics.getTotalForItem(itemId)
        sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    
    return sortedList;
  }

  /// Clear all advanced filters
  void _clearAllFilters() {
    setState(() {
      _selectedFilters.clear();
      _priceRange = const RangeValues(0, 100);
      _bulkSelected.clear();
    });
  }

  /// Toggle bulk selection for an item
  void _toggleBulkSelection(String itemId) {
    setState(() {
      if (_bulkSelected.contains(itemId)) {
        _bulkSelected.remove(itemId);
      } else {
        _bulkSelected.add(itemId);
      }
    });
  }

  /// Bulk toggle availability
  Future<void> _bulkToggleAvailability(List<MenuItem> items) async {
    try {
      final menuService = ref.read(menuServiceProvider);
      
      for (final item in items) {
        if (_bulkSelected.contains(item.id)) {
          await menuService.updateMenuItem(
            item.copyWith(isAvailable: !item.isAvailable),
          );
        }
      }
      
      setState(() {
        _bulkSelected.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Bulk delete items
  Future<void> _bulkDeleteItems(List<MenuItem> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items'),
        content: Text('Are you sure you want to delete ${_bulkSelected.length} items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final menuService = ref.read(menuServiceProvider);
      
      for (final item in items) {
        if (_bulkSelected.contains(item.id)) {
          await menuService.deleteMenuItem(item.id);
        }
      }
      
      setState(() {
        _bulkSelected.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show inline quick edit dialog
  Future<void> _showQuickEditDialog(MenuItem item) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    await showDialog(
      context: context,
      builder: (context) => _QuickEditDialog(
        item: item,
        isMobile: isMobile,
        onSave: (updatedItem) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(menuServiceProvider).updateMenuItem(updatedItem);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Item updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error updating item: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      body: Column(
        children: [
          // Responsive Header - Wrapped in AnimatedBuilder to rebuild on tab change
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              return Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : (isTablet ? 16.0 : 24.0)),
                child: isMobile 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Menu Management',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Mobile actions row - Only show on "All Items" tab
                        if (_tabController.index == 0)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _showAddMenuItemDialog(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _handleImport,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Import'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _handleExport,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Export'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Menu Management',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Spacer(),
                        // Desktop actions - Only show on "All Items" tab
                        if (_tabController.index == 0) ...[
                          OutlinedButton.icon(
                            onPressed: _handleImport,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import CSV'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _handleExport,
                            icon: const Icon(Icons.download),
                            label: const Text('Export CSV'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showAddMenuItemDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Menu Item'),
                          ),
                        ],
                      ],
                    ),
              );
            },
          ),

          // Responsive Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : (isTablet ? 16.0 : 24.0)),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
              // MEDIUM PRIORITY - Tab Indicator Animation
              indicatorSize: TabBarIndicatorSize.label,
              indicator: UnderlineTabIndicator(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  width: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              tabs: [
                Tab(
                  icon: Icon(Icons.inventory_2, size: isMobile ? 20 : 24),
                  text: isMobile ? 'Items' : 'All Menu Items',
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
                ),
                Tab(
                  icon: Icon(Icons.calendar_month, size: isMobile ? 20 : 24),
                  text: isMobile ? 'Weekly' : 'Weekly Menu',
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
                ),
                Tab(
                  icon: Icon(Icons.analytics, size: isMobile ? 20 : 24),
                  text: 'Analytics',
                  iconMargin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content with HIGH PRIORITY - Smooth Tab Transitions
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Mobile: SlideTransition; Desktop: FadeTransition
                    if (isMobile) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    } else {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    }
                  },
                  child: _buildTabContent(
                    _tabController.index,
                    menuItemsAsync,
                    key: ValueKey<int>(_tabController.index), // Prevent jank
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Bulk Actions Bottom Bar (only show on All Items tab with selections)
      bottomNavigationBar: _tabController.index == 0 && _bulkSelected.isNotEmpty
          ? BottomAppBar(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${_bulkSelected.length} selected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final items = menuItemsAsync.value ?? [];
                        await _bulkToggleAvailability(items);
                      },
                      icon: const Icon(Icons.toggle_on),
                      label: const Text('Toggle Availability'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        final items = menuItemsAsync.value ?? [];
                        await _bulkDeleteItems(items);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Selected'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // Helper method to build tab content based on index
  Widget _buildTabContent(int index, AsyncValue<List<MenuItem>> menuItemsAsync, {Key? key}) {
    switch (index) {
      case 0:
        return _buildAllMenuItemsTab(menuItemsAsync);
      case 1:
        return _buildWeeklyMenuTab(menuItemsAsync);
      case 2:
        return _buildAnalyticsTab(menuItemsAsync);
      default:
        return _buildAllMenuItemsTab(menuItemsAsync);
    }
  }

  // Tab 1: All Menu Items - Master Inventory Management
  // Purpose: CRUD operations on food/drink items (Create, Read, Update, Delete)
  // NOT for scheduling - that's Tab 2's job
  // Tab 1: All Menu Items - Master Inventory Management  
  // Purpose: CRUD operations on food/drink items (Create, Read, Update, Delete)
  // NOT for scheduling - that's handled in Tab 2 (Weekly Menu)
  // Tab 1: All Menu Items - Master Inventory Management
  // Purpose: CRUD operations on food/drink items (Create, Read, Update, Delete)
  // NOT for scheduling - that's handled in Tab 2 (Weekly Menu)
  Widget _buildAllMenuItemsTab(AsyncValue<List<MenuItem>> menuItemsAsync) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    return Column(
      children: [
        // Enhanced Filters and Sorting
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : (isTablet ? 16.0 : 24.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search and Sort Row
              isMobile
                ? Column(
                    children: [
                      // Search
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                      const SizedBox(height: 12),
                      // Category and Sort Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All'),
                                ),
                                ...['Snack', 'Lunch', 'Drinks']
                                    .map((category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _sortBy,
                              decoration: const InputDecoration(
                                labelText: 'Sort By',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'name', child: Text('Name (A-Z)')),
                                DropdownMenuItem(value: 'price', child: Text('Price (Low-High)')),
                                DropdownMenuItem(value: 'updated', child: Text('Last Updated')),
                                DropdownMenuItem(value: 'popularity', child: Text('Popularity')),
                              ],
                              onChanged: (value) {
                                setState(() => _sortBy = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Search
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search menu items...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Category Filter
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Categories', overflow: TextOverflow.ellipsis),
                            ),
                            ...['Snack', 'Lunch', 'Drinks']
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category, overflow: TextOverflow.ellipsis),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sort Dropdown
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
                        child: DropdownButtonFormField<String>(
                          initialValue: _sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sort By',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'name', child: Text('Name (A-Z)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'price', child: Text('Price (Low-High)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'updated', child: Text('Last Updated', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'popularity', child: Text('Popularity', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (value) {
                            setState(() => _sortBy = value!);
                          },
                        ),
                      ),
                    ],
                  ),
              
              const SizedBox(height: 12),
              
              // Advanced Filter Chips
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Available'),
                          selected: _selectedFilters.contains('available'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('available');
                                _selectedFilters.remove('unavailable');
                              } else {
                                _selectedFilters.remove('available');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Unavailable'),
                          selected: _selectedFilters.contains('unavailable'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('unavailable');
                                _selectedFilters.remove('available');
                              } else {
                                _selectedFilters.remove('unavailable');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Vegan'),
                          avatar: const Icon(Icons.eco, size: 16),
                          selected: _selectedFilters.contains('vegan'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('vegan');
                              } else {
                                _selectedFilters.remove('vegan');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Vegetarian'),
                          avatar: const Icon(Icons.spa, size: 16),
                          selected: _selectedFilters.contains('vegetarian'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('vegetarian');
                              } else {
                                _selectedFilters.remove('vegetarian');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Gluten-Free'),
                          avatar: const Icon(Icons.grain, size: 16),
                          selected: _selectedFilters.contains('gf'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('gf');
                              } else {
                                _selectedFilters.remove('gf');
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: Text('Price < ${FormatUtils.currency(30)}'),
                          avatar: const Icon(Icons.currency_exchange, size: 16),
                          selected: _selectedFilters.contains('price<30'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFilters.add('price<30');
                              } else {
                                _selectedFilters.remove('price<30');
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFilters.isNotEmpty || _bulkSelected.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Clear All',
                      onPressed: _clearAllFilters,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Menu Items Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: menuItemsAsync.when(
              data: (menuItems) {
                // Apply search and category filters
                var filteredItems = menuItems.where((item) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      item.name.toLowerCase().contains(_searchQuery) ||
                      item.description.toLowerCase().contains(_searchQuery) ||
                      item.category.toLowerCase().contains(_searchQuery);
                  final matchesCategory = _selectedCategory == null ||
                      item.category == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                // Apply advanced filters
                filteredItems = filteredItems.where(_matchesFilters).toList();
                
                // Apply sorting
                filteredItems = _sortMenuItems(filteredItems);

                if (filteredItems.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildMenuGrid(filteredItems);
              },
              loading: () => const LoadingIndicator(text: 'Loading menu items...'),
              error: (error, stack) => Center(
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
                      'Error loading menu items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(error.toString()),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.refresh(menuItemsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyMenuTab(AsyncValue<List<MenuItem>> menuItemsAsync) {
    return menuItemsAsync.when(
      data: (menuItems) {
        return Consumer(
          builder: (context, ref, child) {
            final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
            // Format week start date as YYYY-MM-DD
            final weekStartString = '${_selectedWeek.year.toString().padLeft(4, '0')}-${_selectedWeek.month.toString().padLeft(2, '0')}-${_selectedWeek.day.toString().padLeft(2, '0')}';
            
            return FutureBuilder<WeeklyMenu?>(
              key: ValueKey('menu_$weekStartString$_menuRefreshKey'),
              future: weeklyMenuService.getMenuForWeek(weekStartString),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(text: 'Loading weekly menu...');
                }
                
                final weeklyMenu = snapshot.data;
                _currentMenuByDay = weeklyMenu?.menuByDay ?? _initializeEmptyMenu();
                _isPublished = weeklyMenu?.isPublished ?? false;
                
                return Column(
                  children: [
                    // Week Navigation Header
                    _buildWeekNavigationHeader(weeklyMenuService, weekStartString),
                    
                    const SizedBox(height: 16),
                    
                    // Day Tabs
                    _buildDayTabs(),
                    
                    const SizedBox(height: 16),
                    
                    // Meal Type Sections
                    Expanded(
                      child: _buildMealTypeSections(menuItems, weeklyMenuService, weekStartString),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      loading: () => const LoadingIndicator(text: 'Loading menu items...'),
      error: (error, stack) => Center(
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
              'Error loading menu items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error.toString()),
          ],
        ),
      ),
    );
  }

  // Initialize empty menu structure for new weeks
  Map<String, Map<String, List<String>>> _initializeEmptyMenu() {
    return {
      'Monday': {MealType.snack: [], MealType.lunch: [], MealType.drinks: []},
      'Tuesday': {MealType.snack: [], MealType.lunch: [], MealType.drinks: []},
      'Wednesday': {MealType.snack: [], MealType.lunch: [], MealType.drinks: []},
      'Thursday': {MealType.snack: [], MealType.lunch: [], MealType.drinks: []},
      'Friday': {MealType.snack: [], MealType.lunch: [], MealType.drinks: []},
    };
  }

  // Week Navigation Header with controls
  Widget _buildWeekNavigationHeader(dynamic weeklyMenuService, String weekStartString) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Week Selector
              CompactWeekPicker(
                selectedWeek: _selectedWeek,
                onWeekChanged: (newWeek) {
                  setState(() {
                    _selectedWeek = newWeek;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Mobile actions row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPublished ? null : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await weeklyMenuService.copyMenuFromPreviousWeek(_selectedWeek);
                          if (context.mounted) {
                            setState(() {
                              _menuRefreshKey++;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Copied!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPublished ? null : () => _handlePublishMenu(weeklyMenuService, weekStartString),
                      icon: const Icon(Icons.publish, size: 18),
                      label: const Text('Publish'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              // Week Selector (like analytics tab)
              Expanded(
                child: CompactWeekPicker(
                  selectedWeek: _selectedWeek,
                  onWeekChanged: (newWeek) {
                    setState(() {
                      _selectedWeek = newWeek;
                    });
                  },
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Copy Last Week Button
                OutlinedButton.icon(
                onPressed: _isPublished ? null : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await weeklyMenuService.copyMenuFromPreviousWeek(_selectedWeek);
                    if (context.mounted) {
                      setState(() {
                        _menuRefreshKey++; // Trigger UI refresh
                      });
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Copied menu from last week!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy Last Week'),
              ),
              
              const SizedBox(width: 8),
              
              // Publish Button
              FilledButton.icon(
                onPressed: _isPublished ? null : () => _handlePublishMenu(weeklyMenuService, weekStartString),
                icon: const Icon(Icons.publish),
                label: const Text('Publish Menu'),
              ),
            ],
          ),
    );
  }
  
  // Extract publish logic to separate method for reuse
  Future<void> _handlePublishMenu(dynamic weeklyMenuService, String weekStartString) async {
    // Validate menu
    final validation = weeklyMenuService.validateMenu(_currentMenuByDay);
    if (!validation['isValid']) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Validation Errors'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var error in validation['errors'])
                  Text('• $error'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
              
    // Publish menu
    final messenger = ScaffoldMessenger.of(context);
    try {
      await weeklyMenuService.publishWeeklyMenu(
        weekStartDate: _selectedWeek,
        menuByDay: _currentMenuByDay,
        publishedBy: 'admin',
      );
      if (context.mounted) {
        setState(() {
          _menuRefreshKey++; // Trigger UI refresh
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Weekly menu published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error publishing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Day Tabs (Monday-Friday)
  Widget _buildDayTabs() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      height: isMobile ? 44 : 48,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      child: ShaderMask(
        shaderCallback: (Rect rect) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0.0, 0.05, 0.95, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (context, index) => SizedBox(width: isMobile ? 4 : 8),
          itemBuilder: (context, index) {
            final day = days[index];
            final isSelected = _selectedDay == day;
            final completionStatus = _getDayCompletionStatus(day);
            
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 95 : 140,
                minWidth: isMobile ? 85 : 100,
              ),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isMobile ? day.substring(0, 3) : day,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    Text(
                      completionStatus,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                  ],
                ),
                selected: isSelected,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 6 : 10,
                  vertical: isMobile ? 6 : 8,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDay = day;
                    });
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // Get completion status indicator for a day
  String _getDayCompletionStatus(String day) {
    if (!_currentMenuByDay.containsKey(day)) return '⬜';
    
    final dayMenu = _currentMenuByDay[day]!;
    int filledSections = 0;
    int totalSections = MealType.all.length;
    
    for (var mealType in MealType.all) {
      if (dayMenu[mealType]?.isNotEmpty ?? false) {
        filledSections++;
      }
    }
    
    if (filledSections == 0) return '⬜';
    if (filledSections == totalSections) return '🟩';
    return '🟨';
  }

  // Meal Type Sections with collapsible ExpansionTiles
  Widget _buildMealTypeSections(List<MenuItem> menuItems, dynamic weeklyMenuService, String weekStartString) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text(
          '$_selectedDay Menu',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
        
        // Snack Section
        _buildMealTypeSection(
          mealType: MealType.snack,
          menuItems: menuItems,
          weeklyMenuService: weeklyMenuService,
          weekStartString: weekStartString,
        ),
        
        const SizedBox(height: 8),
        
        // Lunch Section
        _buildMealTypeSection(
          mealType: MealType.lunch,
          menuItems: menuItems,
          weeklyMenuService: weeklyMenuService,
          weekStartString: weekStartString,
        ),
        
        const SizedBox(height: 8),
        
        // Drinks Section
        _buildMealTypeSection(
          mealType: MealType.drinks,
          menuItems: menuItems,
          weeklyMenuService: weeklyMenuService,
          weekStartString: weekStartString,
        ),
      ],
    );
  }

  // Individual Meal Type Section (ExpansionTile)
  Widget _buildMealTypeSection({
    required String mealType,
    required List<MenuItem> menuItems,
    required dynamic weeklyMenuService,
    required String weekStartString,
  }) {
    final selectedItemIds = _currentMenuByDay[_selectedDay]?[mealType] ?? [];
    final selectedItems = menuItems.where((item) => selectedItemIds.contains(item.id)).toList();
    final maxItems = MealType.maxItems[mealType] ?? 5;
    final icon = MealType.icons[mealType] ?? '📋';
    final displayName = MealType.displayNames[mealType] ?? mealType;
    
    return Card(
      elevation: 1,
      child: ExpansionTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          '$displayName (${selectedItems.length}/$maxItems)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected Items List
                if (selectedItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No items added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...selectedItems.map((item) => ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(item.name),
                    subtitle: Text(FormatUtils.currency(item.price)),
                    trailing: _isPublished ? null : IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: () async {
                        await _removeItemFromMenu(
                          weeklyMenuService,
                          weekStartString,
                          _selectedDay,
                          mealType,
                          item.id,
                        );
                      },
                    ),
                  )),
                
                const SizedBox(height: 16),
                
                // Add Item Button
                if (selectedItems.length < maxItems && !_isPublished)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAddItemDialog(
                          menuItems,
                          mealType,
                          displayName,
                          weeklyMenuService,
                          weekStartString,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ),
                
                if (selectedItems.length >= maxItems)
                  Center(
                    child: Text(
                      'Maximum items reached',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Remove item from menu
  Future<void> _removeItemFromMenu(
    dynamic weeklyMenuService,
    String weekStartString,
    String day,
    String mealType,
    String itemId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updatedMenuByDay = Map<String, Map<String, List<String>>>.from(_currentMenuByDay);
      updatedMenuByDay[day] = Map<String, List<String>>.from(updatedMenuByDay[day] ?? {});
      updatedMenuByDay[day]![mealType] = List<String>.from(updatedMenuByDay[day]![mealType] ?? []);
      updatedMenuByDay[day]![mealType]!.remove(itemId);
      await weeklyMenuService.updateWeeklyMenu(weekStartString, updatedMenuByDay);
      
      // Update local state to trigger UI refresh
      setState(() {
        _currentMenuByDay = updatedMenuByDay;
      });
      
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Item removed successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error removing item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show Add Item Dialog
  void _showAddItemDialog(
    List<MenuItem> menuItems,
    String mealType,
    String displayName,
    dynamic weeklyMenuService,
    String weekStartString,
  ) {
    // Filter items by meal type category
    // Drinks meal type shows ONLY Drinks items
    // Lunch meal type shows ONLY Lunch items
    // Snack meal type shows ONLY Snack items
    final availableItems = menuItems.where((item) {
      if (!item.isAvailable) return false;
      
      // Each meal type now shows only its matching category
      if (mealType == MealType.drinks) {
        return item.category == 'Drinks';
      } else if (mealType == MealType.lunch) {
        return item.category == 'Lunch';
      } else {
        // Snack section
        return item.category == 'Snack';
      }
    }).toList();
    
    final selectedItemIds = _currentMenuByDay[_selectedDay]?[mealType] ?? [];
    final unselectedItems = availableItems
        .where((item) => !selectedItemIds.contains(item.id))
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        day: _selectedDay,
        mealType: mealType,
        displayName: displayName,
        availableItems: unselectedItems,
        onItemsSelected: (selectedIds) async {
          await _addItemsToMenu(
            weeklyMenuService,
            weekStartString,
            _selectedDay,
            mealType,
            selectedIds,
          );
        },
        maxItems: MealType.maxItems[mealType] ?? 5,
        currentCount: selectedItemIds.length,
      ),
    );
  }

  // Add items to menu
  Future<void> _addItemsToMenu(
    dynamic weeklyMenuService,
    String weekStartString,
    String day,
    String mealType,
    List<String> itemIds,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updatedMenuByDay = Map<String, Map<String, List<String>>>.from(_currentMenuByDay);
      updatedMenuByDay[day] = Map<String, List<String>>.from(updatedMenuByDay[day] ?? {});
      updatedMenuByDay[day]![mealType] = List<String>.from(updatedMenuByDay[day]![mealType] ?? []);
      updatedMenuByDay[day]![mealType]!.addAll(itemIds);
      await weeklyMenuService.updateWeeklyMenu(weekStartString, updatedMenuByDay);
      
      // Update local state to trigger UI refresh
      setState(() {
        _currentMenuByDay = updatedMenuByDay;
      });
      
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Items added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error adding items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Tab 3: Analytics Dashboard
  Widget _buildAnalyticsTab(AsyncValue<List<MenuItem>> menuItemsAsync) {
    return Consumer(
      builder: (context, ref, child) {
        // Get analytics service
        final analyticsService = ref.watch(weeklyMenuAnalyticsServiceProvider);
        
        // Get menu items
        final menuItems = menuItemsAsync.value ?? [];
        
        // Format week start date as string (yyyy-MM-dd)
        final weekStartString = '${_analyticsWeek.year.toString().padLeft(4, '0')}-${_analyticsWeek.month.toString().padLeft(2, '0')}-${_analyticsWeek.day.toString().padLeft(2, '0')}';

        return Column(
          children: [
            // Week Picker
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  
                  if (isMobile) {
                    // Stack vertically on mobile
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CompactWeekPicker(
                          selectedWeek: _analyticsWeek,
                          onWeekChanged: (newWeek) {
                            setState(() {
                              _analyticsWeek = newWeek;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const WeeklyMenuHistoryScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.history),
                                label: const Text('History'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  try {
                                      final messenger = ScaffoldMessenger.of(context);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Recalculating analytics...'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      await analyticsService.calculateAnalyticsForWeek(weekStartString);
                                      if (context.mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Analytics updated successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error updating analytics: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Horizontal layout for tablet/desktop
                    return Row(
                      children: [
                        Expanded(
                          child: CompactWeekPicker(
                            selectedWeek: _analyticsWeek,
                            onWeekChanged: (newWeek) {
                              setState(() {
                                _analyticsWeek = newWeek;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // History Button
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const WeeklyMenuHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('History'),
                        ),
                        const SizedBox(width: 8),
                        // Refresh Analytics Button
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Recalculating analytics...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              await analyticsService.calculateAnalyticsForWeek(weekStartString);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Analytics updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error updating analytics: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Analytics Content
            Expanded(
              child: StreamBuilder<WeeklyMenuAnalytics?>(
                stream: analyticsService.streamAnalyticsForWeek(weekStartString),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                            'Error loading analytics',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString()),
                        ],
                      ),
                    );
                  }
                  
                  final analytics = snapshot.data;
                  
                  if (analytics == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No analytics available for this week',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Analytics are generated from parent orders',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () async {
                              try {
                                await analyticsService.calculateAnalyticsForWeek(weekStartString);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Analytics calculated!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.calculate),
                            label: const Text('Calculate Analytics'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Display Charts
                  return _buildAnalyticsContent(analytics, analyticsService, weekStartString, menuItems);
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildAnalyticsContent(
    WeeklyMenuAnalytics analytics,
    dynamic analyticsService,
    String weekStartString,
    List<MenuItem> menuItems,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards - Stack on mobile, row on desktop
              if (isMobile)
                Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Orders',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${analytics.totalOrderCounts.values.fold<int>(0, (sum, count) => sum + count)}',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unique Items',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${analytics.totalOrderCounts.keys.length}',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Orders',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${analytics.totalOrderCounts.values.fold<int>(0, (sum, count) => sum + count)}',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.restaurant_menu,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Unique Items',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${analytics.totalOrderCounts.keys.length}',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // View Toggle (Overall vs By Category)
              Row(
                children: [
                  Text(
                    'View: ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Overall'),
                    selected: !_showCategorical,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _showCategorical = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('By Category'),
                    selected: _showCategorical,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _showCategorical = true;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Top Items Chart
              Text(
                _showCategorical ? 'Most Popular Items by Category' : 'Most Popular Items',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: isMobile ? 300 : 340,
                    child: _showCategorical
                        ? CategoricalTopItemsChart(
                            analytics: analytics,
                            menuItems: menuItems,
                          )
                        : TopItemsChart(
                            analytics: analytics,
                            menuItems: menuItems,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Orders Per Day Chart
              Text(
                _showCategorical ? 'Orders by Day (by Category)' : 'Orders by Day',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: _showCategorical
                        ? CategoricalOrdersPerDayChart(
                            analytics: analytics,
                            menuItems: menuItems,
                          )
                        : OrdersPerDayChart(
                            analytics: analytics,
                      menuItems: menuItems,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Weekly Trend Chart
              Text(
                '4-Week Trend',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: FutureBuilder<List<WeeklyMenuAnalytics>>(
                      future: _fetchLast4Weeks(analyticsService, weekStartString),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Center(
                            child: Text(
                              'Unable to load trend data',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }
                        return WeeklyTrendChart(
                          weeklyAnalytics: snapshot.data!,
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Category Distribution Pie Chart
              Text(
                'Category Distribution',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: isMobile ? 280 : 320,
                    child: CategoryPieChart(
                      analytics: analytics,
                      menuItems: menuItems,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<List<WeeklyMenuAnalytics>> _fetchLast4Weeks(
    dynamic analyticsService,
    String currentWeekString,
  ) async {
    final List<WeeklyMenuAnalytics> result = [];
    final currentWeek = DateTime.parse(currentWeekString);
    
    for (int i = 0; i < 4; i++) {
      final week = currentWeek.subtract(Duration(days: 7 * i));
      final weekString = '${week.year.toString().padLeft(4, '0')}-${week.month.toString().padLeft(2, '0')}-${week.day.toString().padLeft(2, '0')}';
      final analytics = await analyticsService.getAnalyticsForWeek(weekString);
      if (analytics != null) {
        result.add(analytics);
      }
    }
    
    return result;
  }

  // Old grid view method removed - now using hybrid day-tabs + meal-type sections UI

  // Old _handlePublishWeeklyMenu method removed - now using inline publish logic in header

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No menu items in inventory',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty && _selectedCategory == null && !_availableOnly
                ? 'Create your first food/drink item to build your menu catalog'
                : 'Try adjusting your filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddMenuItemDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Menu Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(List<MenuItem> menuItems) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // Responsive grid sizing
    final maxCrossAxisExtent = isMobile ? 180.0 : (isTablet ? 240.0 : 320.0);
    final childAspectRatio = isMobile ? 0.75 : 0.68;
    final spacing = isMobile ? 12.0 : 16.0;
    
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return _buildMenuItemCard(item);
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSelected = _bulkSelected.contains(item.id);

    return Semantics(
  label: '${item.name}, ${FormatUtils.currency(item.price)}, ${item.isAvailable ? 'Available' : 'Unavailable'}. ${item.isVegan ? 'Vegan.' : ''} ${item.isGlutenFree ? 'Gluten-free.' : ''}',
      button: true,
      child: GestureDetector(
        onTap: () => _showQuickEditDialog(item),
        onLongPress: () => _toggleBulkSelection(item.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isSelected 
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: isSelected ? 4 : 2,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Expanded(
                        flex: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            item.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.restaurant_menu,
                                        size: 64,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.restaurant_menu,
                                      size: 64,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                            // Gradient Overlay
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.25),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Availability Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Chip(
                                label: Text(
                                  item.isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    color: item.isAvailable
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: item.isAvailable
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.errorContainer,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content - Scrollable Area + Fixed Footer
                      Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Scrollable Content Area with constrained height
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 10.0 : 12.0,
                          isMobile ? 10.0 : 12.0,
                          isMobile ? 10.0 : 12.0,
                          isMobile ? 6.0 : 8.0,
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title and Price
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  FormatUtils.currency(item.price),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 4 : 6),

                            // Category
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 6 : 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isMobile ? 10 : 11,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 4 : 6),

                            // Description
                            Text(
                              item.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.3,
                                fontSize: isMobile ? 11 : 12,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isMobile ? 4 : 6),

                            // Dietary Icons and Allergens
                            Wrap(
                              spacing: 4,
                              runSpacing: 3,
                              children: [
                                if (item.isVegetarian)
                                  Tooltip(
                                    message: 'Vegetarian',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green[700]!, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.eco, size: isMobile ? 12 : 13, color: Colors.green[700]),
                                          const SizedBox(width: 2),
                                          Text('Veg', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.green[700])),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (item.isVegan)
                                  Tooltip(
                                    message: 'Vegan',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green[900]!, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.spa, size: isMobile ? 12 : 13, color: Colors.green[900]),
                                          const SizedBox(width: 2),
                                          Text('Vegan', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.green[900])),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (item.isGlutenFree)
                                  Tooltip(
                                    message: 'Gluten Free',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber[700]!, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.grain, size: isMobile ? 12 : 13, color: Colors.amber[700]),
                                          const SizedBox(width: 2),
                                          Text('GF', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.amber[700])),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (item.allergens.isNotEmpty)
                                  Tooltip(
                                    message: 'Allergens: ${item.allergens.join(", ")}',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange[700]!, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber, size: isMobile ? 12 : 13, color: Colors.orange[700]),
                                          const SizedBox(width: 2),
                                          Text('Allergens', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.orange[700])),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (item.calories != null)
                                  Tooltip(
                                    message: '${item.calories} calories per serving',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue[700]!, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.local_fire_department, size: isMobile ? 12 : 13, color: Colors.blue[700]),
                                          const SizedBox(width: 2),
                                          Text('${item.calories}kcal', style: TextStyle(fontSize: isMobile ? 9 : 10, color: Colors.blue[700])),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (item.stockQuantity != null)
                                  Tooltip(
                                    message: 'Stock: ${item.stockQuantity}',
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 4 : 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: theme.colorScheme.primary, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inventory_2, size: isMobile ? 12 : 13, color: theme.colorScheme.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${item.stockQuantity}',
                                            style: TextStyle(fontSize: isMobile ? 9 : 10, color: theme.colorScheme.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Fixed Footer - Actions (Compact)
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 4 : 6,
                        vertical: isMobile ? 0 : 2,
                      ),
                      height: isMobile ? 36 : 40,
                      child: Row(
                        children: [
                          // Availability Toggle
                          Expanded(
                            child: Transform.scale(
                              scale: isMobile ? 0.75 : 0.8,
                              child: Switch.adaptive(
                                value: item.isAvailable,
                                onChanged: (value) => _toggleAvailability(item),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                thumbColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return theme.colorScheme.onPrimary;
                                  }
                                  return null;
                                }),
                                trackColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return theme.colorScheme.primary;
                                  }
                                  return null;
                                }),
                              ),
                            ),
                          ),
                          // Edit Button
                          IconButton(
                            onPressed: () => _showEditMenuItemDialog(context, item),
                            icon: Icon(Icons.edit_outlined, size: isMobile ? 18 : 19),
                            tooltip: 'Edit',
                            color: theme.colorScheme.primary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.all(isMobile ? 4 : 6),
                            constraints: BoxConstraints(
                              minWidth: isMobile ? 32 : 36,
                              minHeight: isMobile ? 32 : 36,
                            ),
                          ),
                          // Delete Button
                          IconButton(
                            onPressed: () => _confirmDelete(context, item),
                            icon: Icon(Icons.delete_outline, size: isMobile ? 18 : 19),
                            tooltip: 'Delete',
                            color: theme.colorScheme.error,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.all(isMobile ? 4 : 6),
                            constraints: BoxConstraints(
                              minWidth: isMobile ? 32 : 36,
                              minHeight: isMobile ? 32 : 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                    ],
                  ),
                  // Bulk Selection Checkbox Overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: AnimatedOpacity(
                      opacity: _bulkSelected.isNotEmpty || isSelected ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () => _toggleBulkSelection(item.id),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (value) => _toggleBulkSelection(item.id),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(MenuItem item) async {
    try {
      await ref.read(menuServiceProvider).toggleAvailability(item.id, !item.isAvailable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} is now ${!item.isAvailable ? "available" : "unavailable"}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update availability: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showAddMenuItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const MenuItemFormScreen(mode: MenuItemFormMode.add),
    );
  }

  void _showEditMenuItemDialog(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => MenuItemFormScreen(
        mode: MenuItemFormMode.edit,
        menuItem: item,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MenuItem item) async {
    // Capture all context-dependent values before async operations
    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;
    final messenger = ScaffoldMessenger.of(context);
    final itemName = item.name;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Delete image if exists
        if (item.imageUrl != null) {
          await ref.read(storageServiceProvider).deleteMenuItemImage(item.imageUrl!);
        }

        // Delete menu item
        await ref.read(menuServiceProvider).deleteMenuItem(item.id);

        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('$itemName deleted successfully'),
            backgroundColor: primaryColor,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete menu item: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    try {
      // Pick CSV file only
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('No file data');
      }

      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingIndicator(text: 'Importing menu items...'),
      );

      // Import menu items
      final importResult = await (ref.read(menuServiceProvider) as MenuService).importMenuItemsFromFile(
            fileBytes: file.bytes!,
            fileName: file.name,
          );

      if (!mounted) return;
      
      // Close loading dialog using root navigator
      Navigator.of(context, rootNavigator: true).pop();

      // Small delay to allow Firestore stream to update
      await Future.delayed(const Duration(milliseconds: 300));

      // Show result dialog
      final hasErrors = importResult['failed'].isNotEmpty;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                hasErrors ? Icons.warning_amber : Icons.check_circle,
                color: hasErrors
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Import Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Successfully imported: ${importResult['success']} menu item(s)'),
              if (importResult['duplicates'] > 0)
                Text('⚠️  Skipped duplicates: ${importResult['duplicates']} menu item(s)'),
              if (importResult['failed'].isNotEmpty)
                Text('❌ Failed: ${importResult['failed'].length} menu item(s)'),
              if (importResult['failed'].isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Failed entries:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: importResult['failed']
                          .map<Widget>(
                            (error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• Row ${error['row']}: ${error['error']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        // Close loading dialog if open using root navigator
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (popError) {
          AppLogger.debug('Failed to pop loading dialog: $popError');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing menu items: $e')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    try {
      final menuItems = ref.read(menuItemsProvider).value ?? [];
      
      if (menuItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No menu items to export')),
        );
        return;
      }

      final service = ref.read(menuServiceProvider);
  final timestamp = ref.read(dateRefreshProvider).toIso8601String().split('T')[0];
      final fileName = 'menu_items_$timestamp.csv';

      final String csvData = await (service as MenuService).exportMenuItemsToCsv(menuItems);
      final bytes = utf8.encode(csvData);
      _downloadFile(bytes, fileName, 'text/csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${menuItems.length} menu items to $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting menu items: $e')),
        );
      }
    }
  }

  void _downloadFile(List<int> bytes, String fileName, String mimeType) {
    file_download.downloadFile(bytes, fileName, mimeType);
  }
}

// Add Item Dialog Widget
class _AddItemDialog extends StatefulWidget {
  final String day;
  final String mealType;
  final String displayName;
  final List<MenuItem> availableItems;
  final Function(List<String>) onItemsSelected;
  final int maxItems;
  final int currentCount;

  const _AddItemDialog({
    required this.day,
    required this.mealType,
    required this.displayName,
    required this.availableItems,
    required this.onItemsSelected,
    required this.maxItems,
    required this.currentCount,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final Set<String> _selectedItemIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MenuItem> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.availableItems;
    return widget.availableItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final remainingSlots = widget.maxItems - widget.currentCount;
    final canSelectMore = _selectedItemIds.length < remainingSlots;
    
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add ${widget.displayName} Item',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.day} • ${_selectedItemIds.length} selected • $remainingSlots slots available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Items List
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No items available'
                            : 'No items match your search',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = _selectedItemIds.contains(item.id);
                        final canSelect = canSelectMore || isSelected;
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: canSelect ? (value) {
                            setState(() {
                              if (value == true) {
                                _selectedItemIds.add(item.id);
                              } else {
                                _selectedItemIds.remove(item.id);
                              }
                            });
                          } : null,
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.description}\n${FormatUtils.currency(item.price)}',
                          ),
                          isThreeLine: true,
                          secondary: item.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.restaurant),
                                  ),
                                )
                              : const Icon(Icons.restaurant, size: 56),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _selectedItemIds.isEmpty
                      ? null
                      : () {
                          widget.onItemsSelected(_selectedItemIds.toList());
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.add),
                  label: Text('Add ${_selectedItemIds.length} Item${_selectedItemIds.length != 1 ? 's' : ''}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Quick Edit Dialog Widget for inline editing
class _QuickEditDialog extends StatefulWidget {
  final MenuItem item;
  final bool isMobile;
  final Function(MenuItem) onSave;

  const _QuickEditDialog({
    required this.item,
    required this.isMobile,
    required this.onSave,
  });

  @override
  State<_QuickEditDialog> createState() => _QuickEditDialogState();
}

class _QuickEditDialogState extends State<_QuickEditDialog> {
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _caloriesController;
  late bool _isVegan;
  late bool _isVegetarian;
  late bool _isGlutenFree;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _descriptionController = TextEditingController(text: widget.item.description);
    _caloriesController = TextEditingController(text: widget.item.calories?.toString() ?? '');
    _isVegan = widget.item.isVegan;
    _isVegetarian = widget.item.isVegetarian;
    _isGlutenFree = widget.item.isGlutenFree;
    _isAvailable = widget.item.isAvailable;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: BoxConstraints(
          maxWidth: widget.isMobile ? double.infinity : 500,
          maxHeight: widget.isMobile ? 600 : 550,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.edit, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quick Edit: ${widget.item.name}',
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price Field
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (${AppConstants.currencySymbol})',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_exchange),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Dietary Tags
                      Text(
                        'Dietary Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Vegan'),
                            avatar: Icon(
                              _isVegan ? Icons.check_circle : Icons.circle_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _isVegan = !_isVegan);
                            },
                            backgroundColor: _isVegan
                                ? Colors.green.shade100
                                : null,
                          ),
                          ActionChip(
                            label: const Text('Vegetarian'),
                            avatar: Icon(
                              _isVegetarian ? Icons.check_circle : Icons.circle_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _isVegetarian = !_isVegetarian);
                            },
                            backgroundColor: _isVegetarian
                                ? Colors.green.shade100
                                : null,
                          ),
                          ActionChip(
                            label: const Text('Gluten-Free'),
                            avatar: Icon(
                              _isGlutenFree ? Icons.check_circle : Icons.circle_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _isGlutenFree = !_isGlutenFree);
                            },
                            backgroundColor: _isGlutenFree
                                ? Colors.amber.shade100
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Availability
                      SwitchListTile(
                        title: const Text('Available'),
                        subtitle: Text(
                          _isAvailable ? 'Item is available for ordering' : 'Item is currently unavailable',
                        ),
                        value: _isAvailable,
                        onChanged: (value) {
                          setState(() => _isAvailable = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final updatedItem = widget.item.copyWith(
                        price: double.tryParse(_priceController.text) ?? widget.item.price,
                        description: _descriptionController.text,
                        isVegan: _isVegan,
                        isVegetarian: _isVegetarian,
                        isGlutenFree: _isGlutenFree,
                        isAvailable: _isAvailable,
                        updatedAt: DateTime.now(),
                      );
                      widget.onSave(updatedItem);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


