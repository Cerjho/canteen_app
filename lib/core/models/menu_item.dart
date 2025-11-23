import 'package:flutter/foundation.dart';

/// MenuItem model - represents a food/drink item in the master inventory catalog
/// 
/// Purpose: Master inventory management (Tab 1: All Menu Items)
/// - Defines what items exist in the catalog (name, price, description, etc.)
/// - Manages item properties (dietary info, allergens, availability, stock)
/// - NOT for scheduling - use WeeklyMenu model for assigning items to days/weeks
/// 
/// Separation of concerns:
/// - MenuItem = WHAT exists (inventory)
/// - WeeklyMenu = WHEN it's served (schedule)
@immutable
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category; // "Snack", "Lunch", "Drinks"
  final String? imageUrl;
  final List<String> allergens;
  final List<String> dietaryLabels; // ["Vegetarian", "Vegan", "Gluten-Free", etc.]
  final bool isAvailable;
  final int? prepTimeMinutes; // Preparation time in minutes
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.allergens = const [],
    this.dietaryLabels = const [],
    this.isAvailable = true,
    this.prepTimeMinutes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Helper getters for common dietary labels
  bool get isVegetarian => dietaryLabels.any((label) => label.toLowerCase() == 'vegetarian');
  bool get isVegan => dietaryLabels.any((label) => label.toLowerCase() == 'vegan');
  bool get isGlutenFree => dietaryLabels.any((label) => label.toLowerCase().contains('gluten'));


  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image_url': imageUrl,
      'allergens': allergens,
      'dietary_labels': dietaryLabels, // Database uses dietary_labels array
      'is_available': isAvailable,
      'prep_time_minutes': prepTimeMinutes, // Database uses prep_time_minutes
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    // Support legacy boolean fields by converting to dietary_labels
    List<String> dietaryLabels = List<String>.from(map['dietary_labels'] ?? map['dietaryLabels'] ?? []);
    
    // Backward compatibility: if old boolean fields exist, convert them
    if (dietaryLabels.isEmpty) {
      if ((map['is_vegetarian'] ?? map['isVegetarian']) == true) {
        dietaryLabels.add('Vegetarian');
      }
      if ((map['is_vegan'] ?? map['isVegan']) == true) {
        dietaryLabels.add('Vegan');
      }
      if ((map['is_gluten_free'] ?? map['isGlutenFree']) == true) {
        dietaryLabels.add('Gluten-Free');
      }
    }
    
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String,
      imageUrl: (map['image_url'] ?? map['imageUrl']) as String?,
      allergens: List<String>.from(map['allergens'] ?? []),
      dietaryLabels: dietaryLabels,
      isAvailable: (map['is_available'] ?? map['isAvailable']) as bool? ?? true,
      prepTimeMinutes: (map['prep_time_minutes'] ?? map['prepTimeMinutes']) as int?,
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    List<String>? allergens,
    List<String>? dietaryLabels,
    bool? isAvailable,
    int? prepTimeMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      allergens: allergens ?? this.allergens,
      dietaryLabels: dietaryLabels ?? this.dietaryLabels,
      isAvailable: isAvailable ?? this.isAvailable,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
