import 'package:flutter/foundation.dart';

/// Meal Type constants for weekly menu organization
class MealType {
  static const String breakfast = 'breakfast';
  static const String snack = 'snack';
  static const String lunch = 'lunch';
  static const String drinks = 'drinks';
  
  static const List<String> all = [breakfast, snack, lunch, drinks];
  
  static const Map<String, String> displayNames = {
    breakfast: 'Breakfast',
    snack: 'Snack',
    lunch: 'Lunch',
    drinks: 'Drinks',
  };
  
  static const Map<String, String> icons = {
    breakfast: '🍳',
    snack: '🍪',
    lunch: '🍽️',
    drinks: '🥤',
  };
  
  static const Map<String, int> maxItems = {
    breakfast: 5,
    snack: 10,
    lunch: 2,
    drinks: 5,
  };
}

/// Publish status constants
class PublishStatus {
  static const String draft = 'draft';
  static const String published = 'published';
  static const String archived = 'archived';
}

/// Menu Category constants - aligned with MenuItem categories
/// These are the categories used in menu items inventory
class MenuCategory {
  static const String breakfast = 'Breakfast';
  static const String snack = 'Snacks';
  static const String lunch = 'Lunch';
  static const String drinks = 'Drinks';
  
  static const List<String> all = [breakfast, lunch, snack, drinks];
  
  /// Convert MenuCategory to MealType (for weekly menu scheduling)
  static String toMealType(String category) {
    switch (category) {
      case breakfast:
        return MealType.breakfast;
      case snack:
        return MealType.snack;
      case lunch:
        return MealType.lunch;
      case drinks:
        return MealType.drinks;
      default:
        return category.toLowerCase();
    }
  }
  
  /// Convert MealType to MenuCategory (for filtering menu items)
  static String fromMealType(String mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return breakfast;
      case MealType.snack:
        return snack;
      case MealType.lunch:
        return lunch;
      case MealType.drinks:
        return drinks;
      default:
        return mealType.substring(0, 1).toUpperCase() + mealType.substring(1);
    }
  }
}

/// Weekly Menu model - represents a published weekly menu for a specific week
/// Aligned with Supabase schema (2025-11-01)
@immutable
class WeeklyMenu {
  final String id;
  final DateTime weekStart; // Monday of the week
  final Map<String, Map<String, List<String>>> menuItemsByDay; // Day -> MealType -> MenuItem IDs
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String publishStatus; // 'draft' | 'published' | 'archived'
  final int currentVersion; // increments on publish
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  const WeeklyMenu({
    required this.id,
    required this.weekStart,
    required this.menuItemsByDay,
    required this.createdAt,
    this.updatedAt,
    this.publishStatus = PublishStatus.draft,
    this.currentVersion = 0,
    this.publishedAt,
    this.archivedAt,
  });

  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'week_start': weekStart.toIso8601String().split('T')[0], // Date only (YYYY-MM-DD)
      'menu_items_by_day': menuItemsByDay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'publish_status': publishStatus,
      'current_version': currentVersion,
      'published_at': publishedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports snake_case (Postgres) field names
  /// Includes validation for JSONB structure (Fix Issue #6)
  factory WeeklyMenu.fromMap(Map<String, dynamic> map) {
    // Parse nested menuItemsByDay structure: Day -> MealType -> MenuItem IDs
    final Map<String, Map<String, List<String>>> parsedMenuByDay = {};
    final rawMenuByDay = map['menu_items_by_day'] as Map<String, dynamic>? ?? {};
    
    // Validate and parse the JSONB structure
    for (var dayEntry in rawMenuByDay.entries) {
      final day = dayEntry.key;
      
      // Validate day name
      if (!WeeklyMenu.weekdays.contains(day)) {
        print('Warning: Invalid day name "$day" in weekly menu, skipping');
        continue;
      }
      
      // Validate meal types data structure
      if (dayEntry.value is! Map) {
        print('Warning: Invalid meal types structure for day "$day", skipping');
        continue;
      }
      
      final mealTypesData = dayEntry.value as Map<String, dynamic>? ?? {};
      parsedMenuByDay[day] = {};
      
      for (var mealTypeEntry in mealTypesData.entries) {
        final mealType = mealTypeEntry.key;
        
        // Validate meal type
        if (!MealType.all.contains(mealType)) {
          print('Warning: Invalid meal type "$mealType" for day "$day", skipping');
          continue;
        }
        
        // Validate item IDs are a list
        if (mealTypeEntry.value is! List) {
          print('Warning: Invalid item IDs structure for $day/$mealType, using empty list');
          parsedMenuByDay[day]![mealType] = [];
          continue;
        }
        
        // Parse item IDs and validate they are strings
        try {
          final itemIds = List<String>.from(mealTypeEntry.value as List? ?? []);
          parsedMenuByDay[day]![mealType] = itemIds;
        } catch (e) {
          print('Warning: Failed to parse item IDs for $day/$mealType: $e, using empty list');
          parsedMenuByDay[day]![mealType] = [];
        }
      }
    }
    
    return WeeklyMenu(
      id: map['id'] as String,
      weekStart: DateTime.parse(map['week_start'] as String),
      menuItemsByDay: parsedMenuByDay,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      publishStatus: (map['publish_status'] as String?) ?? PublishStatus.draft,
      currentVersion: (map['current_version'] as int?) ?? 0,
      publishedAt: map['published_at'] != null
          ? DateTime.parse(map['published_at'] as String)
          : null,
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  WeeklyMenu copyWith({
    String? id,
    DateTime? weekStart,
    Map<String, Map<String, List<String>>>? menuItemsByDay,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? publishStatus,
    int? currentVersion,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    return WeeklyMenu(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      menuItemsByDay: menuItemsByDay ?? this.menuItemsByDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishStatus: publishStatus ?? this.publishStatus,
      currentVersion: currentVersion ?? this.currentVersion,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  /// Get all weekday keys
  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Get short day names
  static const Map<String, String> shortDayNames = {
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
    'Saturday': 'Sat',
    'Sunday': 'Sun',
  };
}
