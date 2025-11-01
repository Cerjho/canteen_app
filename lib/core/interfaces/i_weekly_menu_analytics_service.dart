import '../models/weekly_menu_analytics.dart';

/// Interface for Weekly Menu Analytics Service operations
/// 
/// This interface defines the contract for weekly menu analytics operations.
abstract class IWeeklyMenuAnalyticsService {
  /// Get analytics for a specific week
  Future<WeeklyMenuAnalytics?> getAnalyticsForWeek(String weekStartDate);

  /// Stream analytics for a specific week
  Stream<WeeklyMenuAnalytics?> streamAnalyticsForWeek(String weekStartDate);

  /// Calculate analytics from orders for a specific week
  Future<WeeklyMenuAnalytics> calculateAnalyticsForWeek(String weekStartDate);

  /// Get analytics for multiple weeks (for comparison)
  Future<List<WeeklyMenuAnalytics>> getAnalyticsForWeeks(List<String> weekStartDates);

  /// Get analytics for the last N weeks
  Future<List<WeeklyMenuAnalytics>> getRecentAnalytics(int numberOfWeeks);

  /// Refresh analytics for a specific week
  Future<WeeklyMenuAnalytics> refreshAnalytics(String weekStartDate);

  /// Delete analytics for a specific week
  Future<void> deleteAnalytics(String weekStartDate);

  /// Get comparison data between two weeks
  Future<Map<String, dynamic>> compareWeeks(
    String week1StartDate,
    String week2StartDate,
  );
}
