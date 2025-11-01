import 'package:cloud_firestore/cloud_firestore.dart';
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
  });

  /// Calculate total price for this cart item
  double get total => price * quantity;

  /// Create from map (for Firestore or local storage)
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      menuItemId: map['menuItemId'] as String,
      name: map['name'] as String,
      imageUrl: map['imageUrl'] as String?,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      category: map['category'] as String,
      addedAt: map['addedAt'] is Timestamp
          ? (map['addedAt'] as Timestamp).toDate()
          : DateTime.parse(map['addedAt'] as String),
      studentId: map['studentId'] as String?,
      studentName: map['studentName'] as String?,
    );
  }

  /// Convert to map (for Firestore or local storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItemId': menuItemId,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'quantity': quantity,
      'category': category,
      'addedAt': Timestamp.fromDate(addedAt),
      'studentId': studentId,
      'studentName': studentName,
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
