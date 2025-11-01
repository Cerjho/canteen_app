import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/i_menu_service.dart';
import '../interfaces/i_weekly_menu_service.dart';
import '../interfaces/i_weekly_menu_analytics_service.dart';
import '../services/menu_service.dart';
import '../services/weekly_menu_service.dart';
import '../services/weekly_menu_analytics_service.dart';
import '../models/menu_item.dart';
import '../models/weekly_menu.dart';
import '../models/weekly_menu_analytics.dart';
import 'supabase_providers.dart';
import 'user_providers.dart';

// ============================================================================
// MENU SERVICE PROVIDERS
// ============================================================================

/// Menu Service Provider
/// 
/// Handles menu item inventory management (CRUD, availability, import/export).
final menuServiceProvider = Provider<IMenuService>((ref) {
  return MenuService(
    supabase: ref.watch(supabaseProvider),
  );
});

/// Weekly Menu Service Provider
/// 
/// Handles weekly menu scheduling (publishing menus, copying, history).
final weeklyMenuServiceProvider = Provider<IWeeklyMenuService>((ref) {
  return WeeklyMenuService(
    supabase: ref.watch(supabaseProvider),
    uuid: ref.watch(uuidProvider),
  );
});

/// Weekly Menu Analytics Service Provider
/// 
/// Handles weekly menu analytics and statistics.
final weeklyMenuAnalyticsServiceProvider = Provider<IWeeklyMenuAnalyticsService>((ref) {
  return WeeklyMenuAnalyticsService(
    supabase: ref.watch(supabaseProvider),
  );
});

// ============================================================================
// MENU DATA PROVIDERS
// ============================================================================

/// All Menu Items Provider
/// 
/// Streams all menu items in the inventory (admin view).
/// Returns: Stream<List<MenuItem>>
final menuItemsProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getMenuItems();
});

/// Available Menu Items Provider
/// 
/// Streams only available menu items (parent view).
/// Returns: Stream<List<MenuItem>>
final availableMenuItemsProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getAvailableMenuItems();
});

/// Current Weekly Menu Provider
/// 
/// Streams the current week's published menu.
/// Returns: Stream<WeeklyMenu?> - null if not published
final currentWeeklyMenuProvider = StreamProvider((ref) {
  return ref.watch(weeklyMenuServiceProvider).getCurrentWeeklyMenu();
});

/// Weekly Menu History Provider
/// 
/// Streams published weekly menus (past menus).
/// Returns: Stream<List<WeeklyMenu>>
final weeklyMenuHistoryProvider = StreamProvider((ref) {
  return ref.watch(weeklyMenuServiceProvider).streamWeeklyMenuHistory(limit: 10);
});

// ============================================================================
// MENU ITEM CATEGORY PROVIDERS
// ============================================================================

/// Breakfast Items Provider
/// 
/// Streams menu items in breakfast category.
/// Returns: Stream<List<MenuItem>>
final breakfastItemsProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getBreakfastItems();
});

/// Lunch Items Provider
/// 
/// Streams menu items in lunch category.
/// Returns: Stream<List<MenuItem>>
final lunchItemsProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getLunchItems();
});

/// Snack Items Provider
/// 
/// Streams menu items in snack category.
/// Returns: Stream<List<MenuItem>>
final snackItemsProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getSnackItems();
});

/// Drinks Provider
/// 
/// Streams menu items in drinks category.
/// Returns: Stream<List<MenuItem>>
final drinksProvider = StreamProvider((ref) {
  return ref.watch(menuServiceProvider).getDrinks();
});

// ============================================================================
// MENU ITEM FAMILY PROVIDERS
// ============================================================================

/// Menu Item by ID Provider Family
/// 
/// Streams a specific menu item by ID.
/// Usage: ref.watch(menuItemByIdProvider(itemId))
/// Returns: Stream<MenuItem?>
final menuItemByIdProvider = StreamProvider.family<MenuItem?, String>((ref, itemId) {
  return ref.watch(menuServiceProvider).getMenuItemStream(itemId);
});

/// Menu Items by Category Provider Family
/// 
/// Streams menu items filtered by category.
/// Usage: ref.watch(menuItemsByCategoryProvider('Breakfast'))
/// Returns: Stream<List<MenuItem>>
final menuItemsByCategoryProvider = StreamProvider.family<List<MenuItem>, String>((ref, category) {
  return ref.watch(menuServiceProvider).getMenuItemsByCategory(category);
});

// ============================================================================
// WEEKLY MENU FAMILY PROVIDERS
// ============================================================================

/// Weekly Menu for Date Provider Family
/// 
/// Streams the published weekly menu for a specific date.
/// Usage: ref.watch(weeklyMenuForDateProvider(date))
/// Returns: Stream<WeeklyMenu?>
final weeklyMenuForDateProvider = StreamProvider.family<WeeklyMenu?, DateTime>((ref, date) {
  final weeklyMenuService = ref.watch(weeklyMenuServiceProvider);
  final mondayOfWeek = _getMondayOfWeek(date);
  final weekStartDate = _formatDate(mondayOfWeek);

  return weeklyMenuService.streamMenuForWeek(weekStartDate);
});

/// Weekly Menu Analytics Provider Family
/// 
/// Streams analytics for a specific week.
/// Usage: ref.watch(weeklyMenuAnalyticsProvider(weekStartDate))
/// Returns: Stream<WeeklyMenuAnalytics?>
final weeklyMenuAnalyticsProvider = StreamProvider.family<WeeklyMenuAnalytics?, String>((ref, weekStartDate) {
  return ref.watch(weeklyMenuAnalyticsServiceProvider).streamAnalyticsForWeek(weekStartDate);
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

DateTime _getMondayOfWeek(DateTime date) {
  return date.subtract(Duration(days: date.weekday - 1));
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
