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
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final bool isAvailable;
  final int? stockQuantity; // null means unlimited
  final int? calories; // Nutritional information - calories per serving
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
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.isAvailable = true,
    this.stockQuantity,
    this.calories,
    required this.createdAt,
    this.updatedAt,
  });

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
      'is_vegetarian': isVegetarian,
      'is_vegan': isVegan,
      'is_gluten_free': isGlutenFree,
      'is_available': isAvailable,
      'stock_quantity': stockQuantity,
      'calories': calories,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String,
      imageUrl: (map['image_url'] ?? map['imageUrl']) as String?,
      allergens: List<String>.from(map['allergens'] ?? []),
      isVegetarian: (map['is_vegetarian'] ?? map['isVegetarian']) as bool? ?? false,
      isVegan: (map['is_vegan'] ?? map['isVegan']) as bool? ?? false,
      isGlutenFree: (map['is_gluten_free'] ?? map['isGlutenFree']) as bool? ?? false,
      isAvailable: (map['is_available'] ?? map['isAvailable']) as bool? ?? true,
      stockQuantity: (map['stock_quantity'] ?? map['stockQuantity']) as int?,
      calories: map['calories'] as int?,
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
    bool? isVegetarian,
    bool? isVegan,
    bool? isGlutenFree,
    bool? isAvailable,
    int? stockQuantity,
    int? calories,
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
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      calories: calories ?? this.calories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
