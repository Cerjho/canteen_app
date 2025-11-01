import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Day-of Order Item - represents items pending approval
class DayOfOrderItem {
  final String id;
  final MenuItem menuItem;
  final int quantity;
  final DateTime selectedDate;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? studentId;
  final String? studentName;

  DayOfOrderItem({
  required this.id,
  required this.menuItem,
  required this.quantity,
  required this.selectedDate,
  this.status = 'pending',
  required this.createdAt,
  this.studentId,
  this.studentName,
  });

  DayOfOrderItem copyWith({
  String? id,
  MenuItem? menuItem,
  int? quantity,
  DateTime? selectedDate,
  String? status,
  DateTime? createdAt,
  String? studentId,
  String? studentName,
  }) {
    return DayOfOrderItem(
      id: id ?? this.id,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      selectedDate: selectedDate ?? this.selectedDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuItemId': menuItem.id,
      'menuItemName': menuItem.name,
      'menuItemPrice': menuItem.price,
      'quantity': quantity,
      'selectedDate': Timestamp.fromDate(selectedDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'studentId': studentId,
      'studentName': studentName,
    };
  }
}

/// Day-of Order State Notifier
class DayOfOrderNotifier extends StateNotifier<List<DayOfOrderItem>> {
  DayOfOrderNotifier() : super([]);

  final _uuid = const Uuid();

  /// Add item to day-of order
  void addItem(MenuItem item, DateTime selectedDate, {String? studentId, String? studentName}) {
    // Check if item already exists for this date
    final existingIndex = state.indexWhere(
      (order) =>
          order.menuItem.id == item.id &&
          order.selectedDate.year == selectedDate.year &&
          order.selectedDate.month == selectedDate.month &&
          order.selectedDate.day == selectedDate.day &&
          order.studentId == studentId,
    );

    if (existingIndex != -1) {
      // Increment quantity
      final updatedItem = state[existingIndex].copyWith(
        quantity: state[existingIndex].quantity + 1,
      );
      state = [
        ...state.sublist(0, existingIndex),
        updatedItem,
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // Add new item
      final newItem = DayOfOrderItem(
        id: _uuid.v4(),
        menuItem: item,
        quantity: 1,
        selectedDate: selectedDate,
        createdAt: DateTime.now(),
        studentId: studentId,
        studentName: studentName,
      );
      state = [...state, newItem];
    }
  }

  /// Remove item from day-of order
  void removeItem(String itemId) {
    state = state.where((item) => item.id != itemId).toList();
  }

  /// Update item quantity
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final index = state.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final updatedItem = state[index].copyWith(quantity: quantity);
      state = [
        ...state.sublist(0, index),
        updatedItem,
        ...state.sublist(index + 1),
      ];
    }
  }

  /// Get items for specific date
  List<DayOfOrderItem> getItemsForDate(DateTime date) {
    return state
        .where((item) =>
            item.selectedDate.year == date.year &&
            item.selectedDate.month == date.month &&
            item.selectedDate.day == date.day)
        .toList();
  }

  /// Submit day-of order for approval
  Future<void> submitForApproval(String parentId, String studentId) async {
    if (state.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Group items by date
    final itemsByDate = <DateTime, List<DayOfOrderItem>>{};
    for (final item in state) {
      final dateKey = DateTime(
        item.selectedDate.year,
        item.selectedDate.month,
        item.selectedDate.day,
      );
      itemsByDate.putIfAbsent(dateKey, () => []).add(item);
    }

    // Create day-of order requests for each date
    for (final entry in itemsByDate.entries) {
      final date = entry.key;
      final items = entry.value;

      final orderId = _uuid.v4();
      final orderRef = firestore.collection('day_of_orders').doc(orderId);

      batch.set(orderRef, {
        'id': orderId,
        'parentId': parentId,
        'studentId': studentId,
        'orderDate': Timestamp.fromDate(date),
        'status': 'pending_approval',
        'items': items.map((item) => item.toMap()).toList(),
        'totalAmount': items.fold<double>(
          0,
          (sum, item) => sum + (item.menuItem.price * item.quantity),
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Clear state after submission
    state = [];
  }

  /// Clear all day-of orders
  void clear() {
    state = [];
  }

  /// Get total items count
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);

  /// Get total amount
  double get totalAmount => state.fold(
        0,
        (sum, item) => sum + (item.menuItem.price * item.quantity),
      );
}

/// Provider for day-of orders
final dayOfOrderProvider =
    StateNotifierProvider<DayOfOrderNotifier, List<DayOfOrderItem>>(
  (ref) => DayOfOrderNotifier(),
);

/// Provider for day-of order item count
final dayOfOrderItemCountProvider = Provider<int>((ref) {
  final dayOfOrders = ref.watch(dayOfOrderProvider);
  return dayOfOrders.fold(0, (sum, item) => sum + item.quantity);
});

/// Provider for day-of order total amount
final dayOfOrderTotalProvider = Provider<double>((ref) {
  final dayOfOrders = ref.watch(dayOfOrderProvider);
  return dayOfOrders.fold(
    0,
    (sum, item) => sum + (item.menuItem.price * item.quantity),
  );
});
