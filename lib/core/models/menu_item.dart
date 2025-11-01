import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'allergens': allergens,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
      'isGlutenFree': isGlutenFree,
      'isAvailable': isAvailable,
      'stockQuantity': stockQuantity,
      'calories': calories,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String,
      imageUrl: map['imageUrl'] as String?,
      allergens: List<String>.from(map['allergens'] ?? []),
      isVegetarian: map['isVegetarian'] as bool? ?? false,
      isVegan: map['isVegan'] as bool? ?? false,
      isGlutenFree: map['isGlutenFree'] as bool? ?? false,
      isAvailable: map['isAvailable'] as bool? ?? true,
      stockQuantity: map['stockQuantity'] as int?,
      calories: map['calories'] as int?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
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
