import '../models/weekly_menu.dart';
import '../models/menu_item.dart';

/// Interface for Weekly Menu Service operations
/// 
/// This interface defines the contract for weekly menu management operations.
abstract class IWeeklyMenuService {
  /// Get the current week's menu
  Stream<WeeklyMenu?> getCurrentWeeklyMenu();

  /// Get weekly menu by date
  Future<WeeklyMenu?> getWeeklyMenuByDate(DateTime date);

  /// Get all published weekly menus
  Stream<List<WeeklyMenu>> getPublishedWeeklyMenus({int limit});

  /// Publish a new weekly menu
  Future<void> publishWeeklyMenu({
    required DateTime weekStartDate,
    required Map<String, Map<String, List<String>>> menuByDay,
    String? publishedBy,
    String? copiedFromWeek,
  });

  /// Unpublish a weekly menu
  Future<void> unpublishWeeklyMenu(String menuId);

  /// Delete a weekly menu
  Future<void> deleteWeeklyMenu(String menuId);

  /// Update weekly menu data
  Future<void> updateWeeklyMenu(
    String weekStartDate,
    Map<String, Map<String, List<String>>> menuByDay,
  );

  /// Get menu items for a specific day and meal type
  Future<List<MenuItem>> getMenuItemsForDay(
    WeeklyMenu weeklyMenu,
    String day, {
    String? mealType,
  });

  /// Update menu items' availability
  Future<void> updateMenuItemsAvailability(
    Map<String, Map<String, List<String>>> menuByDay,
  );

  /// Copy menu from previous week
  Future<void> copyMenuFromPreviousWeek(DateTime targetWeekStart);

  /// Get weekly menu history
  Future<List<WeeklyMenu>> getWeeklyMenuHistory({int limit});

  /// Stream weekly menu history
  Stream<List<WeeklyMenu>> streamWeeklyMenuHistory({int limit});

  /// Get menu for a specific week
  Future<WeeklyMenu?> getMenuForWeek(String weekStartDate);

  /// Stream menu for a specific week
  Stream<WeeklyMenu?> streamMenuForWeek(String weekStartDate);

  /// Validate menu structure and item limits
  Map<String, dynamic> validateMenu(Map<String, Map<String, List<String>>> menuByDay);

  /// Get week date range as string
  String getWeekDateRange(DateTime monday);
}
