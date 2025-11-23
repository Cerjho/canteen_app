import 'package:flutter/foundation.dart';

/// Order Item - individual items in an order
@immutable
class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final double price;
  final int quantity;

  const OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'menuItemName': menuItemName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: (map['menuItemId'] ?? map['menu_item_id']) as String,
      menuItemName: (map['menuItemName'] ?? map['menu_item_name']) as String,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Order Status
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Order Type
enum OrderType {
  oneTime('one-time'),
  weekly('weekly');

  final String value;
  const OrderType(this.value);

  static OrderType fromString(String value) {
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => OrderType.oneTime,
    );
  }
}

/// Order model - represents a food order placed by a student
@immutable
class Order {
  final String id;
  final String orderNumber;
  final String parentId;
  final String studentId;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final OrderType orderType;
  final DateTime deliveryDate;
  final String? deliveryTime;
  final String? specialInstructions;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.parentId,
    required this.studentId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.orderType,
    required this.deliveryDate,
    this.deliveryTime,
    this.specialInstructions,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'parent_id': parentId,
      'student_id': studentId,
      'items': items.map((item) => item.toMap()).toList(),
      'total_amount': totalAmount,
      'status': status.name,
      'order_type': orderType.value,
      'delivery_date': deliveryDate.toIso8601String().split('T')[0], // DATE format
      'delivery_time': deliveryTime,
      'special_instructions': specialInstructions,
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory Order.fromMap(Map<String, dynamic> map) {
    // Handle missing required fields gracefully
    final id = map['id'] as String;
    final orderNumber = (map['order_number'] ?? map['orderNumber'] ?? id) as String;
    final parentId = (map['parent_id'] ?? map['parentId'] ?? '') as String;
    final studentId = (map['student_id'] ?? map['studentId'] ?? '') as String;
    
    // items may be null or in mixed casing; normalize safely
    final rawItems = (map['items'] as List?) ?? const [];
    final parsedItems = rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) => OrderItem.fromMap(item))
        .toList();

    // total amount may be missing/null; compute from items as fallback
    double totalAmount;
    final totalRaw = map['total_amount'] ?? map['totalAmount'];
    if (totalRaw is num) {
      totalAmount = totalRaw.toDouble();
    } else {
      totalAmount = parsedItems.fold<double>(0.0, (sum, it) => sum + it.total);
    }

    // delivery_date may be String (ISO) or DateTime
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.parse(v);
      throw ArgumentError('Invalid date value: $v');
    }

    return Order(
      id: id,
      orderNumber: orderNumber,
      parentId: parentId,
      studentId: studentId,
      items: parsedItems,
      totalAmount: totalAmount,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      orderType: OrderType.fromString((map['order_type'] ?? map['orderType'] ?? 'one-time') as String),
      deliveryDate: parseDate(map['delivery_date'] ?? map['deliveryDate']),
      deliveryTime: (map['delivery_time'] ?? map['deliveryTime']) as String?,
      specialInstructions: (map['special_instructions'] ?? map['specialInstructions']) as String?,
      completedAt: (map['completed_at'] ?? map['completedAt']) != null
          ? parseDate(map['completed_at'] ?? map['completedAt'])
          : null,
      cancelledAt: (map['cancelled_at'] ?? map['cancelledAt']) != null
          ? parseDate(map['cancelled_at'] ?? map['cancelledAt'])
          : null,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? parseDate(map['updated_at'] ?? map['updatedAt'])
          : null,
    );
  }

  /// Create a copy with modified fields
  Order copyWith({
    String? id,
    String? orderNumber,
    String? parentId,
    String? studentId,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    OrderType? orderType,
    DateTime? deliveryDate,
    String? deliveryTime,
    String? specialInstructions,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      parentId: parentId ?? this.parentId,
      studentId: studentId ?? this.studentId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
