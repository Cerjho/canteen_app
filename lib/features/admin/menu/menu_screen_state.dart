import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/date_refresh_provider.dart';

// ============================================================================
// MENU SCREEN UI STATE
// ============================================================================

/// UI State for Menu Screen
/// 
/// Manages all local UI state including filters, search, sorting, bulk selection,
/// week selection, and day selection.
class MenuScreenUiState {
  // Tab 1: All Menu Items filters
  final String searchQuery;
  final String? selectedCategory;
  final String sortBy; // 'name', 'price', 'popularity', 'updated'
  final Set<String> selectedFilters; // 'available', 'unavailable', 'vegan', 'gf', etc.
  final RangeValues priceRange;
  final Set<String> bulkSelected; // Item IDs selected for bulk operations

  // Tab 2: Weekly Menu state
  final DateTime selectedWeek; // Always Monday of the week
  final String selectedDay; // 'Monday' - 'Sunday'

  // Tab 3: Analytics state
  final DateTime analyticsWeek; // Always Monday of the week
  final bool showCategorical; // Toggle for categorical view

  const MenuScreenUiState({
    this.searchQuery = '',
    this.selectedCategory,
    this.sortBy = 'name',
    this.selectedFilters = const {},
    this.priceRange = const RangeValues(0, 100),
    this.bulkSelected = const {},
    required this.selectedWeek,
    this.selectedDay = 'Monday',
    required this.analyticsWeek,
    this.showCategorical = false,
  });

  MenuScreenUiState copyWith({
    String? searchQuery,
    String? selectedCategory,
    String? sortBy,
    Set<String>? selectedFilters,
    RangeValues? priceRange,
    Set<String>? bulkSelected,
    DateTime? selectedWeek,
    String? selectedDay,
    DateTime? analyticsWeek,
    bool? showCategorical,
  }) {
    return MenuScreenUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortBy: sortBy ?? this.sortBy,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      priceRange: priceRange ?? this.priceRange,
      bulkSelected: bulkSelected ?? this.bulkSelected,
      selectedWeek: selectedWeek ?? this.selectedWeek,
      selectedDay: selectedDay ?? this.selectedDay,
      analyticsWeek: analyticsWeek ?? this.analyticsWeek,
      showCategorical: showCategorical ?? this.showCategorical,
    );
  }
}

// ============================================================================
// MENU SCREEN STATE NOTIFIER
// ============================================================================

/// Menu Screen State Notifier
/// 
/// Manages all UI state for the menu screen in a centralized, immutable way.
/// Replaces scattered `setState` calls with a clean API.
class MenuScreenStateNotifier extends StateNotifier<MenuScreenUiState> {
  final Ref ref;

  MenuScreenStateNotifier(this.ref) : super(_initialState(ref));

  static MenuScreenUiState _initialState(Ref ref) {
    final now = ref.read(dateRefreshProvider);
    final monday = _getMondayOfWeek(now);
    return MenuScreenUiState(
      selectedWeek: monday,
      analyticsWeek: monday,
    );
  }

  static DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // ============================================================================
  // TAB 1: ALL MENU ITEMS - Filters & Search
  // ============================================================================

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void toggleFilter(String filter) {
    final filters = Set<String>.from(state.selectedFilters);
    if (filters.contains(filter)) {
      filters.remove(filter);
    } else {
      filters.add(filter);
    }
    state = state.copyWith(selectedFilters: filters);
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      selectedFilters: {},
      priceRange: const RangeValues(0, 100),
    );
  }

  void clearAllFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      selectedFilters: {},
      priceRange: const RangeValues(0, 100),
      bulkSelected: {},
    );
  }

  void setPriceRange(RangeValues range) {
    state = state.copyWith(priceRange: range);
  }

  // ============================================================================
  // BULK SELECTION
  // ============================================================================

  void toggleBulkSelection(String itemId) {
    final selected = Set<String>.from(state.bulkSelected);
    if (selected.contains(itemId)) {
      selected.remove(itemId);
    } else {
      selected.add(itemId);
    }
    state = state.copyWith(bulkSelected: selected);
  }

  void selectAll(List<String> itemIds) {
    state = state.copyWith(bulkSelected: itemIds.toSet());
  }

  void clearBulkSelection() {
    state = state.copyWith(bulkSelected: {});
  }

  // ============================================================================
  // TAB 2: WEEKLY MENU - Week & Day Selection
  // ============================================================================

  void setSelectedWeek(DateTime week) {
    final monday = _getMondayOfWeek(week);
    state = state.copyWith(selectedWeek: monday);
  }

  void setSelectedDay(String day) {
    state = state.copyWith(selectedDay: day);
  }

  void previousWeek() {
    final newWeek = state.selectedWeek.subtract(const Duration(days: 7));
    state = state.copyWith(selectedWeek: newWeek);
  }

  void nextWeek() {
    final newWeek = state.selectedWeek.add(const Duration(days: 7));
    state = state.copyWith(selectedWeek: newWeek);
  }

  // ============================================================================
  // TAB 3: ANALYTICS - Week Selection
  // ============================================================================

  void setAnalyticsWeek(DateTime week) {
    final monday = _getMondayOfWeek(week);
    state = state.copyWith(analyticsWeek: monday);
  }

  void setShowCategorical(bool value) {
    state = state.copyWith(showCategorical: value);
  }

  void toggleCategoricalView() {
    state = state.copyWith(showCategorical: !state.showCategorical);
  }

  void previousAnalyticsWeek() {
    final newWeek = state.analyticsWeek.subtract(const Duration(days: 7));
    state = state.copyWith(analyticsWeek: newWeek);
  }

  void nextAnalyticsWeek() {
    final newWeek = state.analyticsWeek.add(const Duration(days: 7));
    state = state.copyWith(analyticsWeek: newWeek);
  }
}

// ============================================================================
// MENU SCREEN STATE PROVIDER
// ============================================================================

final menuScreenStateProvider = StateNotifierProvider<MenuScreenStateNotifier, MenuScreenUiState>((ref) {
  return MenuScreenStateNotifier(ref);
});

// ============================================================================
// FILTERED MENU ITEMS PROVIDER
// ============================================================================

/// Filtered Menu Items Provider
/// 
/// Applies all filters, search, and sorting to menu items.
/// Only rebuilds when filters or data change, not the entire screen.
final filteredMenuItemsProvider = Provider<List<MenuItem>>((ref) {
  final itemsAsync = ref.watch(menuItemsProvider);
  final state = ref.watch(menuScreenStateProvider);

  // Return empty list while loading
  if (!itemsAsync.hasValue) return [];

  var items = itemsAsync.value ?? [];

  // Apply search
  if (state.searchQuery.isNotEmpty) {
    final query = state.searchQuery.toLowerCase();
    items = items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();
  }

  // Apply category filter
  if (state.selectedCategory != null && state.selectedCategory!.isNotEmpty) {
    items = items.where((item) => item.category == state.selectedCategory).toList();
  }

  // Apply advanced filters
  if (state.selectedFilters.isNotEmpty) {
    items = items.where((item) => _matchesFilters(item, state.selectedFilters)).toList();
  }

  // Apply price range
  items = items.where((item) {
    return item.price >= state.priceRange.start && item.price <= state.priceRange.end;
  }).toList();

  // Apply sorting
  switch (state.sortBy) {
    case 'price':
      items.sort((a, b) => a.price.compareTo(b.price));
      break;
    case 'price-desc':
      items.sort((a, b) => b.price.compareTo(a.price));
      break;
    case 'updated':
      items.sort((a, b) {
        final aUpdated = a.updatedAt ?? a.createdAt;
        final bUpdated = b.updatedAt ?? b.createdAt;
        return bUpdated.compareTo(aUpdated);
      });
      break;
    case 'name':
    default:
      items.sort((a, b) => a.name.compareTo(b.name));
      break;
  }

  return items;
});

/// Helper function to check if item matches selected filters
bool _matchesFilters(MenuItem item, Set<String> filters) {
  for (final filter in filters) {
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
      case 'gluten-free':
        if (!item.isGlutenFree) return false;
        break;
      case 'price<30':
        if (item.price >= 30) return false;
        break;
      case 'price<50':
        if (item.price >= 50) return false;
        break;
    }
  }
  return true;
}

// ============================================================================
// WEEKLY MENU PROVIDER (Replaces FutureBuilder)
// ============================================================================

/// Weekly Menu Provider Family
/// 
/// Provides weekly menu for a specific week start date.
/// Replaces FutureBuilder + _menuRefreshKey hack.
/// 
/// Usage: ref.watch(weeklyMenuProvider(weekStartString))
final weeklyMenuProvider = FutureProvider.family<Map<String, Map<String, List<String>>>, String>((ref, weekStart) async {
  // Access WeeklyMenuService via central app providers
  final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);

  try {
    final weeklyMenu = await weeklyMenuService.getMenuForWeek(weekStart);
    if (weeklyMenu == null) {
      // No menu for this week yet
      return {};
    }

    // Normalize structure to ensure all expected keys exist and use DB keys (lowercase)
    final Map<String, Map<String, List<String>>> menuByDay = {};
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final day in days) {
      final dayMenu = weeklyMenu.menuItemsByDay[day] ?? const {};
      menuByDay[day] = {
        'breakfast': List<String>.from(dayMenu['breakfast'] ?? const <String>[]),
        'lunch': List<String>.from(dayMenu['lunch'] ?? const <String>[]),
        'snack': List<String>.from(dayMenu['snack'] ?? const <String>[]),
        'drinks': List<String>.from(dayMenu['drinks'] ?? const <String>[]),
      };
    }

    return menuByDay;
  } catch (_) {
    // On error, return empty structure; UI shows error from provider.when(error: ...)
    return {};
  }
});

/// Weekly Menu Entity Provider (for status/version awareness)
final weeklyMenuEntityProvider = FutureProvider.family<WeeklyMenu?, String>((ref, weekStart) async {
  final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
  try {
    return await weeklyMenuService.getMenuForWeek(weekStart);
  } catch (_) {
    return null;
  }
});

/// Stream of published weekly menus (for customer-facing reads or dashboards)
final publishedWeeklyMenusProvider = StreamProvider.autoDispose<List<WeeklyMenu>>((ref) {
  final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
  return weeklyMenuService.getPublishedWeeklyMenus(limit: 50);
});
