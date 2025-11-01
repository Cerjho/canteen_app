import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weekly_menu_analytics.dart';
import '../constants/database_constants.dart';
import '../interfaces/i_weekly_menu_analytics_service.dart';

/// Service for calculating and managing weekly menu analytics
class WeeklyMenuAnalyticsService implements IWeeklyMenuAnalyticsService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  WeeklyMenuAnalyticsService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Get analytics for a specific week
  @override
  Future<WeeklyMenuAnalytics?> getAnalyticsForWeek(String weekStartDate) async {
    try {
      final querySnapshot = await _supabase
          .from('menu_analytics')
          .eq(DatabaseConstants.weekStartDate, weekStartDate)
          .limit(1)
          .get();

      if (querydata.isEmpty) {
        return null;
      }

      return WeeklyMenuAnalytics.fromMap(query(data as List).first);
    } catch (e) {
      throw Exception('Failed to get analytics for week: $e');
    }
  }

  /// Stream analytics for a specific week
  @override
  Stream<WeeklyMenuAnalytics?> streamAnalyticsForWeek(String weekStartDate) {
    return _supabase
        .from('menu_analytics')
        .eq(DatabaseConstants.weekStartDate, weekStartDate)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (data.isEmpty) return null;
      return WeeklyMenuAnalytics.fromMap((data as List).first);
    });
  }

  /// Calculate analytics from orders collection for a specific week
  @override
  Future<WeeklyMenuAnalytics> calculateAnalyticsForWeek(
    String weekStartDate,
  ) async {
    try {
      // Parse week start date
      final weekStart = DateTime.parse(weekStartDate);
      final weekEnd = weekStart.add(const Duration(days: 7));

      // Initialize data structures
      final Map<String, List<String>> popularItemsByDay = {};
      final Map<String, int> totalOrderCounts = {};
      final Map<String, Map<String, int>> orderCountsByDay = {};
      final Map<String, int> ordersByMealType = {};
      int totalOrders = 0;

      // Query orders for this week
      final ordersSnapshot = await _supabase
          .from('orders')
          .gte(DatabaseConstants.orderDate, weekStart.toIso8601String())
          .lt(DatabaseConstants.orderDate, weekEnd.toIso8601String())
          .get();

      // Process each order
      for (var orderDoc in ordersdata) {
        final orderData = orderdata;
        final orderDate = (orderData[DatabaseConstants.orderDate] as Timestamp).toDate();
        final dayName = _getDayName(orderDate.weekday);
        
        // Get items from order
        final items = orderData[DatabaseConstants.items] as List<dynamic>? ?? [];
        
        for (var item in items) {
          final itemId = item[DatabaseConstants.menuItemId] as String?;
          final mealType = item[DatabaseConstants.mealType] as String? ?? 'unknown';
          final quantity = item[DatabaseConstants.quantity] as int? ?? 1;
          
          if (itemId == null) continue;
          
          // Update total order counts
          totalOrderCounts[itemId] = (totalOrderCounts[itemId] ?? 0) + quantity;
          totalOrders += quantity;
          
          // Update orders by day
          orderCountsByDay[dayName] ??= {};
          orderCountsByDay[dayName]![itemId] = 
              (orderCountsByDay[dayName]![itemId] ?? 0) + quantity;
          
          // Update orders by meal type
          ordersByMealType[mealType] = 
              (ordersByMealType[mealType] ?? 0) + quantity;
        }
      }

      // Calculate popular items by day (sort by order count)
      for (var day in orderCountsByDay.keys) {
        final sortedItems = orderCountsByDay[day]!.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        popularItemsByDay[day] = sortedItems.map((e) => e.key).toList();
      }

      // Create analytics object
      final analytics = WeeklyMenuAnalytics(
        id: 'analytics_$weekStartDate',
        weekStartDate: weekStartDate,
        popularItemsByDay: popularItemsByDay,
        totalOrderCounts: totalOrderCounts,
        orderCountsByDay: orderCountsByDay,
        ordersByMealType: ordersByMealType,
        totalOrders: totalOrders,
        calculatedAt: DateTime.now(),
      );

      // Save to Firestore
      await _supabase
          .from('menu_analytics')
          .doc(analytics.id)
          .set(analytics.toMap());

      return analytics;
    } catch (e) {
      throw Exception('Failed to calculate analytics: $e');
    }
  }

  /// Get analytics for multiple weeks (for comparison)
  @override
  Future<List<WeeklyMenuAnalytics>> getAnalyticsForWeeks(
    List<String> weekStartDates,
  ) async {
    try {
      final analytics = <WeeklyMenuAnalytics>[];
      
      for (var weekStartDate in weekStartDates) {
        final weekAnalytics = await getAnalyticsForWeek(weekStartDate);
        if (weekAnalytics != null) {
          analytics.add(weekAnalytics);
        }
      }
      
      return analytics;
    } catch (e) {
      throw Exception('Failed to get analytics for weeks: $e');
    }
  }

  /// Get analytics for the last N weeks
  @override
  Future<List<WeeklyMenuAnalytics>> getRecentAnalytics(int numberOfWeeks) async {
    try {
      final querySnapshot = await _supabase
          .from('menu_analytics')
          .order(DatabaseConstants.weekStartDate, ascending: false)
          .limit(numberOfWeeks)
          .get();

      return querydata
          .map((doc) => WeeklyMenuAnalytics.fromMap(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent analytics: $e');
    }
  }

  /// Refresh analytics for a specific week (recalculate from orders)
  @override
  Future<WeeklyMenuAnalytics> refreshAnalytics(String weekStartDate) async {
    return await calculateAnalyticsForWeek(weekStartDate);
  }

  /// Delete analytics for a specific week
  @override
  Future<void> deleteAnalytics(String weekStartDate) async {
    try {
      final querySnapshot = await _supabase
          .from('menu_analytics')
          .eq(DatabaseConstants.weekStartDate, weekStartDate)
          .get();

      for (var doc in querydata) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete analytics: $e');
    }
  }

  /// Helper method to get day name from weekday number
  String _getDayName(int weekday) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return dayNames[weekday - 1];
  }

  /// Get comparison data between two weeks
  @override
  Future<Map<String, dynamic>> compareWeeks(
    String week1StartDate,
    String week2StartDate,
  ) async {
    try {
      final analytics1 = await getAnalyticsForWeek(week1StartDate);
      final analytics2 = await getAnalyticsForWeek(week2StartDate);

      if (analytics1 == null || analytics2 == null) {
        throw Exception('Analytics not found for one or both weeks');
      }

      // Calculate differences
      final orderDifference = analytics2.totalOrders - analytics1.totalOrders;
      final percentageChange = analytics1.totalOrders > 0
          ? ((orderDifference / analytics1.totalOrders) * 100)
          : 0.0;

      return {
        'week1': analytics1,
        'week2': analytics2,
        'orderDifference': orderDifference,
        'percentageChange': percentageChange,
        'averageOrdersWeek1': analytics1.averageOrdersPerDay,
        'averageOrdersWeek2': analytics2.averageOrdersPerDay,
      };
    } catch (e) {
      throw Exception('Failed to compare weeks: $e');
    }
  }
}
