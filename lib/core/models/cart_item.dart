import 'package:flutter/foundation.dart';

/// CartItem model - represents an item in the shopping cart
/// 
/// Used for parent ordering flow:
/// - Temporary storage before order placement
/// - Quantity management
/// - Price calculation
@immutable
class CartItem {
  final String id; // Unique cart item ID
  final String menuItemId; // Reference to MenuItem
  final String name;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String category;
  final DateTime addedAt;
  final String? studentId;
  final String? studentName;
  final String? deliveryTime; // e.g., '09:00', '12:00', '14:00'
  final String? specialInstructions;

  const CartItem({
  required this.id,
  required this.menuItemId,
  required this.name,
  this.imageUrl,
  required this.price,
  required this.quantity,
  required this.category,
  required this.addedAt,
  this.studentId,
  this.studentName,
  this.deliveryTime,
  this.specialInstructions,
  });

  /// Calculate total price for this cart item
  double get total => price * quantity;

  /// Create from map (for database or local storage)
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory CartItem.fromMap(Map<String, dynamic> map) {
    // Parse addedAt - support both ISO8601 strings and legacy formats
    final addedAtValue = map['added_at'] ?? map['addedAt'];
    DateTime parsedAddedAt;
    if (addedAtValue is String) {
      parsedAddedAt = DateTime.parse(addedAtValue);
    } else {
      // Fallback for unexpected formats - use current time
      parsedAddedAt = DateTime.now();
    }
    
    return CartItem(
      id: map['id'] as String,
      menuItemId: (map['menu_item_id'] ?? map['menuItemId']) as String,
      name: map['name'] as String,
      imageUrl: (map['image_url'] ?? map['imageUrl']) as String?,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      category: map['category'] as String,
      addedAt: parsedAddedAt,
      studentId: (map['student_id'] ?? map['studentId']) as String?,
      studentName: (map['student_name'] ?? map['studentName']) as String?,
      deliveryTime: (map['delivery_time'] ?? map['deliveryTime']) as String?,
      specialInstructions: (map['special_instructions'] ?? map['specialInstructions']) as String?,
    );
  }

  /// Convert to map (for database or local storage)
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'name': name,
      'image_url': imageUrl,
      'price': price,
      'quantity': quantity,
      'category': category,
      'added_at': addedAt.toIso8601String(),
      'student_id': studentId,
      'student_name': studentName,
      'delivery_time': deliveryTime,
      'special_instructions': specialInstructions,
    };
  }

  /// Create a copy with modified fields
  CartItem copyWith({
  String? id,
  String? menuItemId,
  String? name,
  String? imageUrl,
  double? price,
  int? quantity,
  String? category,
  DateTime? addedAt,
  String? studentId,
  String? studentName,
  String? deliveryTime,
  String? specialInstructions,
  }) {
    return CartItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      addedAt: addedAt ?? this.addedAt,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, quantity: $quantity, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.id == id &&
        other.menuItemId == menuItemId &&
    other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(id, menuItemId, quantity);
}
