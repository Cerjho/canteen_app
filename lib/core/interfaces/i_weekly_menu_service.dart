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

  /// Get all published weekly menus (filters by publish_status = 'published')
  Stream<List<WeeklyMenu>> getPublishedWeeklyMenus({int limit});

  /// Publish a weekly menu for a given week
  /// Sets publish_status to 'published', increments version, and snapshots to versions table
  Future<void> publishWeeklyMenu({
    required DateTime weekStartDate,
    required Map<String, Map<String, List<String>>> menuByDay,
  });

  /// Delete a weekly menu
  Future<void> deleteWeeklyMenu(String menuId);

  /// Update weekly menu data (keeps menu in 'draft' until published)
  Future<void> updateWeeklyMenu(
    String weekStartDate,
    Map<String, Map<String, List<String>>> menuByDay,
  );

  /// Unpublish a weekly menu (set status to 'draft')
  Future<void> unpublishWeeklyMenu(DateTime weekStartDate);

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

  /// List versions for a week's menu (latest first)
  Future<List<Map<String, dynamic>>> getWeeklyMenuVersions(DateTime weekStartDate);

  /// Revert a week's menu content to a specific version (keeps status as draft)
  Future<void> revertToVersion(DateTime weekStartDate, int version);

  /// Archive a week's menu (set status to archived)
  Future<void> archiveWeeklyMenu(DateTime weekStartDate);
}
