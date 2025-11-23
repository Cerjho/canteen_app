import 'menu_item.dart';

/// Analytics model for tracking weekly menu performance and ordering patterns
class WeeklyMenuAnalytics {
  final String id;
  final String weekStartDate; // Format: YYYY-MM-DD (Monday of the week) - maps to week_start in DB
  final Map<String, List<String>> popularItemsByDay; // Day -> List of MenuItem IDs (ordered by popularity)
  final Map<String, int> totalOrderCounts; // MenuItem ID -> Total orders across all days
  final Map<String, Map<String, int>> orderCountsByDay; // Day -> MenuItem ID -> Order count
  final Map<String, int> ordersByMealType; // MealType -> Total orders
  final int totalOrders; // Total orders for the week
  final DateTime calculatedAt; // When analytics were last calculated
  final DateTime? updatedAt;

  WeeklyMenuAnalytics({
    required this.id,
    required this.weekStartDate,
    required this.popularItemsByDay,
    required this.totalOrderCounts,
    required this.orderCountsByDay,
    required this.ordersByMealType,
    required this.totalOrders,
    required this.calculatedAt,
    this.updatedAt,
  });

  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'week_start': weekStartDate, // Database uses week_start
      'analytics_data': {
        'popular_items_by_day': popularItemsByDay,
        'total_order_counts': totalOrderCounts,
        'order_counts_by_day': orderCountsByDay,
        'orders_by_meal_type': ordersByMealType,
      },
      'total_orders': totalOrders,
      'created_at': calculatedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory WeeklyMenuAnalytics.fromMap(Map<String, dynamic> map) {
    // Get analytics_data JSONB field or fall back to individual fields
    final analyticsData = map['analytics_data'] as Map<String, dynamic>? ?? {};
    
    // Parse popularItemsByDay
    final Map<String, List<String>> parsedPopularItems = {};
    final rawPopularItems = (analyticsData['popular_items_by_day'] ?? 
                             map['popular_items_by_day'] ?? 
                             map['popularItemsByDay'] ?? 
                             {}) as Map<String, dynamic>;
    for (var entry in rawPopularItems.entries) {
      parsedPopularItems[entry.key] = List<String>.from(entry.value as List);
    }

    // Parse totalOrderCounts
    final Map<String, int> parsedTotalCounts = {};
    final rawTotalCounts = (analyticsData['total_order_counts'] ?? 
                           map['total_order_counts'] ?? 
                           map['totalOrderCounts'] ?? 
                           {}) as Map<String, dynamic>;
    for (var entry in rawTotalCounts.entries) {
      parsedTotalCounts[entry.key] = entry.value as int;
    }

    // Parse orderCountsByDay
    final Map<String, Map<String, int>> parsedOrdersByDay = {};
    final rawOrdersByDay = (analyticsData['order_counts_by_day'] ?? 
                           map['order_counts_by_day'] ?? 
                           map['orderCountsByDay'] ?? 
                           {}) as Map<String, dynamic>;
    for (var dayEntry in rawOrdersByDay.entries) {
      final day = dayEntry.key;
      final itemCounts = dayEntry.value as Map<String, dynamic>;
      parsedOrdersByDay[day] = {};
      for (var itemEntry in itemCounts.entries) {
        parsedOrdersByDay[day]![itemEntry.key] = itemEntry.value as int;
      }
    }

    // Parse ordersByMealType
    final Map<String, int> parsedMealTypeCounts = {};
    final rawMealTypeCounts = (analyticsData['orders_by_meal_type'] ?? 
                              map['orders_by_meal_type'] ?? 
                              map['ordersByMealType'] ?? 
                              {}) as Map<String, dynamic>;
    for (var entry in rawMealTypeCounts.entries) {
      parsedMealTypeCounts[entry.key] = entry.value as int;
    }

    return WeeklyMenuAnalytics(
      id: map['id'] as String,
      weekStartDate: (map['week_start'] ?? map['week_start_date'] ?? map['weekStartDate']) as String,
      popularItemsByDay: parsedPopularItems,
      totalOrderCounts: parsedTotalCounts,
      orderCountsByDay: parsedOrdersByDay,
      ordersByMealType: parsedMealTypeCounts,
      totalOrders: (map['total_orders'] ?? map['totalOrders'] ?? 0) as int,
      calculatedAt: DateTime.parse((map['created_at'] ?? map['calculatedAt'] ?? DateTime.now().toIso8601String()) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  WeeklyMenuAnalytics copyWith({
    String? id,
    String? weekStartDate,
    Map<String, List<String>>? popularItemsByDay,
    Map<String, int>? totalOrderCounts,
    Map<String, Map<String, int>>? orderCountsByDay,
    Map<String, int>? ordersByMealType,
    int? totalOrders,
    DateTime? calculatedAt,
    DateTime? updatedAt,
  }) {
    return WeeklyMenuAnalytics(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      popularItemsByDay: popularItemsByDay ?? this.popularItemsByDay,
      totalOrderCounts: totalOrderCounts ?? this.totalOrderCounts,
      orderCountsByDay: orderCountsByDay ?? this.orderCountsByDay,
      ordersByMealType: ordersByMealType ?? this.ordersByMealType,
      totalOrders: totalOrders ?? this.totalOrders,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get top N most popular items across all days
  List<MapEntry<String, int>> getTopItems(int n) {
    final sorted = totalOrderCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Get total orders for a specific day
  int getOrdersForDay(String day) {
    if (!orderCountsByDay.containsKey(day)) return 0;
    return orderCountsByDay[day]!.values.fold(0, (sum, count) => sum + count);
  }

  /// Get average orders per day
  double get averageOrdersPerDay {
    if (orderCountsByDay.isEmpty) return 0.0;
    final totalDays = orderCountsByDay.keys.length;
    return totalOrders / totalDays;
  }

  /// Get total orders for a specific category
  int getTotalForCategory(String category, List<MenuItem> menuItems) {
    final itemMap = {for (var item in menuItems) item.id: item};
    int total = 0;
    
    for (var entry in totalOrderCounts.entries) {
      final item = itemMap[entry.key];
      if (item?.category.toLowerCase() == category.toLowerCase()) {
        total += entry.value;
      }
    }
    
    return total;
  }

  /// Get top N items by category
  Map<String, List<MapEntry<String, int>>> getTopByCategory(
    int limit,
    List<MenuItem> menuItems,
  ) {
    final itemMap = {for (var item in menuItems) item.id: item};
    final Map<String, List<MapEntry<String, int>>> categoryMap = {};

    // Group items by category
    for (var entry in totalOrderCounts.entries) {
      final item = itemMap[entry.key];
      if (item != null) {
        final category = item.category;
        categoryMap.putIfAbsent(category, () => []);
        categoryMap[category]!.add(entry);
      }
    }

    // Sort and limit each category
    final result = <String, List<MapEntry<String, int>>>{};
    for (var category in categoryMap.keys) {
      final sorted = categoryMap[category]!
        ..sort((a, b) => b.value.compareTo(a.value));
      result[category] = sorted.take(limit).toList();
    }

    return result;
  }

  /// Get top 3 items by category for a specific day
  Map<String, List<CategoricalTopItem>> getTop3ForDayByCategory(
    String day,
    List<MenuItem> menuItems,
  ) {
    final itemMap = {for (var item in menuItems) item.id: item};
    final dayOrders = orderCountsByDay[day] ?? {};
    final Map<String, List<MapEntry<String, int>>> categoryMap = {};

    // Group day's items by category
    for (var entry in dayOrders.entries) {
      final item = itemMap[entry.key];
      if (item != null) {
        final category = item.category;
        categoryMap.putIfAbsent(category, () => []);
        categoryMap[category]!.add(entry);
      }
    }

    // Calculate top 3 per category with percentages
    final result = <String, List<CategoricalTopItem>>{};
    final dayTotal = getOrdersForDay(day);

    for (var category in categoryMap.keys) {
      final sorted = categoryMap[category]!
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3 = sorted.take(3).toList();

      // Calculate category total for percentage
      final categoryTotal = sorted.fold(0, (sum, e) => sum + e.value);

      result[category] = top3.map((entry) {
        final item = itemMap[entry.key];
        return CategoricalTopItem(
          itemId: entry.key,
          itemName: item?.name ?? 'Unknown',
          category: category,
          orders: entry.value,
          percentageOfCategory: categoryTotal > 0 
              ? (entry.value / categoryTotal * 100) 
              : 0.0,
          percentageOfDay: dayTotal > 0 
              ? (entry.value / dayTotal * 100) 
              : 0.0,
        );
      }).toList();
    }

    return result;
  }

  /// Get dominant category for a day
  String? getDominantCategoryForDay(String day, List<MenuItem> menuItems) {
    final itemMap = {for (var item in menuItems) item.id: item};
    final dayOrders = orderCountsByDay[day] ?? {};
    final Map<String, int> categoryCounts = {};

    for (var entry in dayOrders.entries) {
      final item = itemMap[entry.key];
      if (item != null) {
        categoryCounts[item.category] = 
            (categoryCounts[item.category] ?? 0) + entry.value;
      }
    }

    if (categoryCounts.isEmpty) return null;

    // Find category with most orders
    return categoryCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

/// Model for categorical top item with percentage data
class CategoricalTopItem {
  final String itemId;
  final String itemName;
  final String category;
  final int orders;
  final double percentageOfCategory;
  final double percentageOfDay;

  CategoricalTopItem({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.orders,
    required this.percentageOfCategory,
    required this.percentageOfDay,
  });
}
