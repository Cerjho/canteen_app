import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekStartDate': weekStartDate,
      'copiedFromWeek': copiedFromWeek,
      'menuByDay': menuByDay,
      'isPublished': isPublished,
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'publishedBy': publishedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory WeeklyMenu.fromMap(Map<String, dynamic> map) {
    // Parse nested menuByDay structure: Day -> MealType -> MenuItem IDs
    final Map<String, Map<String, List<String>>> parsedMenuByDay = {};
    final rawMenuByDay = map['menuByDay'] as Map<String, dynamic>? ?? {}; // Null-safe
    
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
      weekStartDate: map['weekStartDate'] as String,
      copiedFromWeek: map['copiedFromWeek'] as String?,
      menuByDay: parsedMenuByDay,
      isPublished: map['isPublished'] as bool? ?? false,
      publishedAt: map['publishedAt'] != null
          ? (map['publishedAt'] as Timestamp).toDate()
          : null, // Null-safe for unpublished menus
      publishedBy: map['publishedBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
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
