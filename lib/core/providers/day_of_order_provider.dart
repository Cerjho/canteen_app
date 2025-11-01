import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import 'package:uuid/uuid.dart';
import 'supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      'menu_item_id': menuItem.id,
      'menu_item_name': menuItem.name,
      'menu_item_price': menuItem.price,
      'quantity': quantity,
      'selected_date': selectedDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'student_id': studentId,
      'student_name': studentName,
    };
  }
}

/// Day-of Order State Notifier
class DayOfOrderNotifier extends StateNotifier<List<DayOfOrderItem>> {
  DayOfOrderNotifier(this._supabase) : super([]);

  final _uuid = const Uuid();
  final SupabaseClient _supabase;

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
    final now = DateTime.now();
    final orders = <Map<String, dynamic>>[];
    
    for (final entry in itemsByDate.entries) {
      final date = entry.key;
      final items = entry.value;

      final orderId = _uuid.v4();
      orders.add({
        'id': orderId,
        'parent_id': parentId,
        'student_id': studentId,
        'order_date': date.toIso8601String(),
        'status': 'pending_approval',
        'items': items.map((item) => item.toMap()).toList(),
        'total_amount': items.fold<double>(
          0,
          (sum, item) => sum + (item.menuItem.price * item.quantity),
        ),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    // Insert all orders
    await _supabase.from('day_of_orders').insert(orders);

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
  (ref) => DayOfOrderNotifier(ref.watch(supabaseProvider)),
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
