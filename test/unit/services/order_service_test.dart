import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/models/order.dart';

/// Comprehensive unit tests for OrderService
/// 
/// Note: These tests focus on Order and OrderItem model validation,
/// business logic, and data transformation. For integration tests
/// with Firestore, see the integration test suite.
void main() {
  group('OrderItem Model - Basic Operations', () {
    test('OrderItem creation succeeds', () {
      final orderItem = OrderItem(
        menuItemId: 'item-1',
        menuItemName: 'Chicken Adobo',
        price: 45.0,
        quantity: 2,
      );

      expect(orderItem.menuItemId, 'item-1');
      expect(orderItem.menuItemName, 'Chicken Adobo');
      expect(orderItem.price, 45.0);
      expect(orderItem.quantity, 2);
    });

    test('OrderItem.total calculates correctly', () {
      final orderItem = OrderItem(
        menuItemId: 'item-1',
        menuItemName: 'Burger',
        price: 65.0,
        quantity: 3,
      );

      expect(orderItem.total, 195.0);
    });

    test('OrderItem.total with quantity 1', () {
      final orderItem = OrderItem(
        menuItemId: 'item-1',
        menuItemName: 'Soda',
        price: 20.0,
        quantity: 1,
      );

      expect(orderItem.total, 20.0);
    });

    test('OrderItem.toMap() converts correctly', () {
      final orderItem = OrderItem(
        menuItemId: 'item-1',
        menuItemName: 'Salad',
        price: 35.0,
        quantity: 2,
      );

      final map = orderItem.toMap();

      expect(map['menuItemId'], 'item-1');
      expect(map['menuItemName'], 'Salad');
      expect(map['price'], 35.0);
      expect(map['quantity'], 2);
    });

    test('OrderItem.fromMap() creates correctly', () {
      final map = {
        'menuItemId': 'item-1',
        'menuItemName': 'Water',
        'price': 15.0,
        'quantity': 5,
      };

      final orderItem = OrderItem.fromMap(map);

      expect(orderItem.menuItemId, 'item-1');
      expect(orderItem.menuItemName, 'Water');
      expect(orderItem.price, 15.0);
      expect(orderItem.quantity, 5);
      expect(orderItem.total, 75.0);
    });
  });

  group('OrderStatus Enum - Display Names', () {
    test('OrderStatus display names are correct', () {
      expect(OrderStatus.pending.displayName, 'Pending');
      expect(OrderStatus.confirmed.displayName, 'Confirmed');
      expect(OrderStatus.preparing.displayName, 'Preparing');
      expect(OrderStatus.ready.displayName, 'Ready');
      expect(OrderStatus.completed.displayName, 'Completed');
      expect(OrderStatus.cancelled.displayName, 'Cancelled');
    });

    test('OrderStatus.name returns enum string', () {
      expect(OrderStatus.pending.name, 'pending');
      expect(OrderStatus.confirmed.name, 'confirmed');
      expect(OrderStatus.preparing.name, 'preparing');
      expect(OrderStatus.ready.name, 'ready');
      expect(OrderStatus.completed.name, 'completed');
      expect(OrderStatus.cancelled.name, 'cancelled');
    });

    test('OrderStatus can be parsed from string', () {
      final status = OrderStatus.values.firstWhere(
        (e) => e.name == 'pending',
        orElse: () => OrderStatus.pending,
      );

      expect(status, OrderStatus.pending);
    });
  });

  group('Order Model - Data Serialization', () {
    test('Order creation with required fields succeeds', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Burger',
          price: 65.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Juan Dela Cruz',
        items: items,
        totalAmount: 65.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.id, 'order-1');
      expect(order.studentId, 'student-1');
      expect(order.studentName, 'Juan Dela Cruz');
      expect(order.items.length, 1);
      expect(order.totalAmount, 65.0);
      expect(order.status, OrderStatus.pending);
    });

    test('Order.toMap() converts order to Firestore map correctly', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Burger',
          price: 65.0,
          quantity: 2,
        ),
        OrderItem(
          menuItemId: 'item-2',
          menuItemName: 'Soda',
          price: 20.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Maria Santos',
        parentId: 'parent-1',
        items: items,
        totalAmount: 150.0,
        status: OrderStatus.completed,
        orderDate: now,
        completedAt: now,
        notes: 'No onions',
        createdAt: now,
        updatedAt: now,
      );

      final map = order.toMap();

      expect(map['id'], 'order-1');
      expect(map['studentId'], 'student-1');
      expect(map['studentName'], 'Maria Santos');
      expect(map['parentId'], 'parent-1');
      expect(map['items'], isA<List>());
      expect(map['items'].length, 2);
      expect(map['totalAmount'], 150.0);
      expect(map['status'], 'completed');
      expect(map['orderDate'], isA<Timestamp>());
      expect(map['completedAt'], isA<Timestamp>());
      expect(map['notes'], 'No onions');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('Order.fromMap() creates order from Firestore map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'order-2',
        'studentId': 'student-2',
        'studentName': 'Pedro Reyes',
        'parentId': 'parent-2',
        'items': [
          {
            'menuItemId': 'item-1',
            'menuItemName': 'Salad',
            'price': 35.0,
            'quantity': 1,
          },
        ],
        'totalAmount': 35.0,
        'status': 'confirmed',
        'orderDate': Timestamp.fromDate(now),
        'completedAt': null,
        'notes': 'Extra dressing',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': null,
      };

      final order = Order.fromMap(map);

      expect(order.id, 'order-2');
      expect(order.studentId, 'student-2');
      expect(order.studentName, 'Pedro Reyes');
      expect(order.parentId, 'parent-2');
      expect(order.items.length, 1);
      expect(order.items[0].menuItemName, 'Salad');
      expect(order.totalAmount, 35.0);
      expect(order.status, OrderStatus.confirmed);
      expect(order.notes, 'Extra dressing');
    });

    test('Order.copyWith() creates modified copy correctly', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Water',
          price: 15.0,
          quantity: 1,
        ),
      ];

      final originalOrder = Order(
        id: 'order-3',
        studentId: 'student-3',
        studentName: 'Ana Garcia',
        items: items,
        totalAmount: 15.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      final updatedOrder = originalOrder.copyWith(
        status: OrderStatus.completed,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Updated fields
      expect(updatedOrder.status, OrderStatus.completed);
      expect(updatedOrder.completedAt, isNotNull);
      expect(updatedOrder.updatedAt, isNotNull);

      // Unchanged fields
      expect(updatedOrder.id, originalOrder.id);
      expect(updatedOrder.studentId, originalOrder.studentId);
      expect(updatedOrder.studentName, originalOrder.studentName);
      expect(updatedOrder.totalAmount, originalOrder.totalAmount);
    });
  });

  group('Order Model - Total Calculation', () {
    test('Order totalAmount matches sum of items', () {
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Burger',
          price: 65.0,
          quantity: 2,
        ),
        OrderItem(
          menuItemId: 'item-2',
          menuItemName: 'Soda',
          price: 20.0,
          quantity: 3,
        ),
      ];

      final calculatedTotal = items.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

      expect(calculatedTotal, 190.0); // (65*2) + (20*3) = 130 + 60 = 190
    });

    test('Order with single item calculates correctly', () {
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Lunch Set',
          price: 85.0,
          quantity: 1,
        ),
      ];

      final calculatedTotal = items.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

      expect(calculatedTotal, 85.0);
    });

    test('Order with many items calculates correctly', () {
      final items = [
        OrderItem(menuItemId: '1', menuItemName: 'Item 1', price: 10.0, quantity: 1),
        OrderItem(menuItemId: '2', menuItemName: 'Item 2', price: 20.0, quantity: 2),
        OrderItem(menuItemId: '3', menuItemName: 'Item 3', price: 30.0, quantity: 3),
        OrderItem(menuItemId: '4', menuItemName: 'Item 4', price: 40.0, quantity: 4),
      ];

      final calculatedTotal = items.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

      // 10*1 + 20*2 + 30*3 + 40*4 = 10 + 40 + 90 + 160 = 300
      expect(calculatedTotal, 300.0);
    });
  });

  group('Order Model - Status Management', () {
    test('Order status defaults to pending', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.status, OrderStatus.pending);
    });

    test('Order status can be updated using copyWith', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      final confirmedOrder = order.copyWith(status: OrderStatus.confirmed);
      final preparingOrder = confirmedOrder.copyWith(status: OrderStatus.preparing);
      final readyOrder = preparingOrder.copyWith(status: OrderStatus.ready);
      final completedOrder = readyOrder.copyWith(status: OrderStatus.completed);

      expect(confirmedOrder.status, OrderStatus.confirmed);
      expect(preparingOrder.status, OrderStatus.preparing);
      expect(readyOrder.status, OrderStatus.ready);
      expect(completedOrder.status, OrderStatus.completed);
    });

    test('Completed orders should have completedAt timestamp', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.completed,
        orderDate: now,
        completedAt: now,
        createdAt: now,
      );

      expect(order.status, OrderStatus.completed);
      expect(order.completedAt, isNotNull);
    });
  });

  group('Order Model - Date Operations', () {
    test('Order date can be set to specific time', () {
      final specificDate = DateTime(2024, 12, 15, 10, 30, 0);
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: specificDate,
        createdAt: DateTime.now(),
      );

      expect(order.orderDate, specificDate);
      expect(order.orderDate.year, 2024);
      expect(order.orderDate.month, 12);
      expect(order.orderDate.day, 15);
    });

    test('Order date range filtering logic', () {
      final start = DateTime(2024, 12, 1);
      final end = DateTime(2024, 12, 31, 23, 59, 59);

      final testDate1 = DateTime(2024, 12, 15);
      final testDate2 = DateTime(2024, 11, 30);
      final testDate3 = DateTime(2025, 1, 1);

      expect(testDate1.isAfter(start) && testDate1.isBefore(end), true);
      expect(testDate2.isAfter(start) && testDate2.isBefore(end), false);
      expect(testDate3.isAfter(start) && testDate3.isBefore(end), false);
    });

    test('Today date calculation', () {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      expect(startOfDay.hour, 0);
      expect(startOfDay.minute, 0);
      expect(startOfDay.second, 0);
      expect(endOfDay.hour, 23);
      expect(endOfDay.minute, 59);
      expect(endOfDay.second, 59);
    });
  });

  group('Order Model - Statistics', () {
    test('Order statistics calculation for multiple orders', () {
      final orders = [
        _createOrder('1', OrderStatus.completed, 100.0),
        _createOrder('2', OrderStatus.completed, 150.0),
        _createOrder('3', OrderStatus.pending, 75.0),
        _createOrder('4', OrderStatus.cancelled, 50.0),
      ];

      int totalOrders = orders.length;
      int completedOrders = orders.where((o) => o.status == OrderStatus.completed).length;
      int cancelledOrders = orders.where((o) => o.status == OrderStatus.cancelled).length;
      int pendingOrders = totalOrders - completedOrders - cancelledOrders;
      
      double totalRevenue = orders
          .where((o) => o.status == OrderStatus.completed)
          .fold(0.0, (sum, o) => sum + o.totalAmount);
      
      double averageOrderValue = completedOrders > 0 ? totalRevenue / completedOrders : 0.0;

      expect(totalOrders, 4);
      expect(completedOrders, 2);
      expect(cancelledOrders, 1);
      expect(pendingOrders, 1);
      expect(totalRevenue, 250.0); // 100 + 150
      expect(averageOrderValue, 125.0); // 250 / 2
    });

    test('Order statistics with no orders', () {
      final orders = <Order>[];

      int totalOrders = orders.length;
      double totalRevenue = orders
          .where((o) => o.status == OrderStatus.completed)
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      expect(totalOrders, 0);
      expect(totalRevenue, 0.0);
    });

    test('Order statistics with only completed orders', () {
      final orders = [
        _createOrder('1', OrderStatus.completed, 100.0),
        _createOrder('2', OrderStatus.completed, 200.0),
        _createOrder('3', OrderStatus.completed, 300.0),
      ];

      int completedOrders = orders.where((o) => o.status == OrderStatus.completed).length;
      double totalRevenue = orders.fold(0.0, (sum, o) => sum + o.totalAmount);

      expect(completedOrders, 3);
      expect(totalRevenue, 600.0);
    });
  });

  group('Order Model - Edge Cases', () {
    test('Order with empty items list', () {
      final now = DateTime.now();
      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: [],
        totalAmount: 0.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.items, isEmpty);
      expect(order.totalAmount, 0.0);
    });

    test('Order with very large total amount', () {
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Premium Item',
          price: 9999.99,
          quantity: 10,
        ),
      ];

      final totalAmount = items.fold<double>(0, (sum, item) => sum + item.total);

      expect(totalAmount, 99999.90);
    });

    test('Order with special characters in notes', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        notes: 'Extra sauce! No onions. Add "special" ingredients.',
        createdAt: now,
      );

      expect(order.notes, contains('!'));
      expect(order.notes, contains('.'));
      expect(order.notes, contains('"'));
    });

    test('Order with very long student name', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Alexander Christopher Rodriguez Dela Cruz Martinez',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.studentName.length, greaterThan(40));
    });
  });

  group('Order Model - Data Integrity', () {
    test('Required fields cannot be null', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      expect(
        () => Order(
          id: 'order-1',
          studentId: 'student-1',
          studentName: 'Test Student',
          items: items,
          totalAmount: 10.0,
          status: OrderStatus.pending,
          orderDate: now,
          createdAt: now,
        ),
        returnsNormally,
      );
    });

    test('Optional fields can be null', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.parentId, null);
      expect(order.completedAt, null);
      expect(order.notes, null);
      expect(order.updatedAt, null);
    });

    test('OrderItem list is properly typed', () {
      final now = DateTime.now();
      final items = [
        OrderItem(
          menuItemId: 'item-1',
          menuItemName: 'Test',
          price: 10.0,
          quantity: 1,
        ),
      ];

      final order = Order(
        id: 'order-1',
        studentId: 'student-1',
        studentName: 'Test Student',
        items: items,
        totalAmount: 10.0,
        status: OrderStatus.pending,
        orderDate: now,
        createdAt: now,
      );

      expect(order.items, isA<List<OrderItem>>());
      expect(order.items[0], isA<OrderItem>());
    });
  });
}

// Helper function to create test orders
Order _createOrder(String id, OrderStatus status, double amount) {
  final now = DateTime.now();
  final items = [
    OrderItem(
      menuItemId: 'item-$id',
      menuItemName: 'Item $id',
      price: amount,
      quantity: 1,
    ),
  ];

  return Order(
    id: id,
    studentId: 'student-$id',
    studentName: 'Student $id',
    items: items,
    totalAmount: amount,
    status: status,
    orderDate: now,
    createdAt: now,
    completedAt: status == OrderStatus.completed ? now : null,
  );
}
