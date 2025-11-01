import 'package:flutter/foundation.dart';

/// Meal Type constants for weekly menu organization
class MealType {
  static const String snack = 'snack';
  static const String lunch = 'lunch';
  static const String drinks = 'drinks';
  
  static const List<String> all = [snack, lunch, drinks];
  
  static const Map<String, String> displayNames = {
    snack: 'Snack',
    lunch: 'Lunch',
    drinks: 'Drinks',
  };
  
  static const Map<String, String> icons = {
    snack: '🍪',
    lunch: '🍽️',
    drinks: '🥤',
  };
  
  static const Map<String, int> maxItems = {
    snack: 10,
    lunch: 2,
    drinks: 5,
  };
}

/// Weekly Menu model - represents a published weekly menu for a specific week (V2.0)
@immutable
class WeeklyMenu {
  final String id;
  final String weekStartDate; // Format: YYYY-MM-DD (Monday of the week)
  final String? copiedFromWeek; // Week this menu was copied from
  final Map<String, Map<String, List<String>>> menuByDay; // Day -> MealType -> MenuItem IDs
  final bool isPublished;
  final DateTime? publishedAt; // Null if not yet published
  final String? publishedBy; // Admin user ID
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WeeklyMenu({
    required this.id,
    required this.weekStartDate,
    this.copiedFromWeek,
    required this.menuByDay,
    required this.isPublished,
    this.publishedAt, // Optional now
    this.publishedBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'week_start_date': weekStartDate,
      'copied_from_week': copiedFromWeek,
      'menu_by_day': menuByDay,
      'is_published': isPublished,
      'published_at': publishedAt?.toIso8601String(),
      'published_by': publishedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory WeeklyMenu.fromMap(Map<String, dynamic> map) {
    // Parse nested menuByDay structure: Day -> MealType -> MenuItem IDs
    final Map<String, Map<String, List<String>>> parsedMenuByDay = {};
    final rawMenuByDay = (map['menu_by_day'] ?? map['menuByDay']) as Map<String, dynamic>? ?? {}; // Null-safe
    
    for (var dayEntry in rawMenuByDay.entries) {
      final day = dayEntry.key;
      final mealTypesData = dayEntry.value as Map<String, dynamic>? ?? {};
      
      parsedMenuByDay[day] = {};
      for (var mealTypeEntry in mealTypesData.entries) {
        final mealType = mealTypeEntry.key;
        final itemIds = List<String>.from(mealTypeEntry.value as List? ?? []);
        parsedMenuByDay[day]![mealType] = itemIds;
      }
    }
    
    return WeeklyMenu(
      id: map['id'] as String,
      weekStartDate: (map['week_start_date'] ?? map['weekStartDate']) as String,
      copiedFromWeek: (map['copied_from_week'] ?? map['copiedFromWeek']) as String?,
      menuByDay: parsedMenuByDay,
      isPublished: (map['is_published'] ?? map['isPublished']) as bool? ?? false,
      publishedAt: (map['published_at'] ?? map['publishedAt']) != null
          ? DateTime.parse((map['published_at'] ?? map['publishedAt']) as String)
          : null, // Null-safe for unpublished menus
      publishedBy: (map['published_by'] ?? map['publishedBy']) as String?,
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  WeeklyMenu copyWith({
    String? id,
    String? weekStartDate,
    String? copiedFromWeek,
    Map<String, Map<String, List<String>>>? menuByDay,
    bool? isPublished,
    DateTime? publishedAt,
    String? publishedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeeklyMenu(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      copiedFromWeek: copiedFromWeek ?? this.copiedFromWeek,
      menuByDay: menuByDay ?? this.menuByDay,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get all weekday keys
  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  /// Get short day names
  static const Map<String, String> shortDayNames = {
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
  };
}
