import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart' as app_models;
import '../constants/database_constants.dart';
import '../interfaces/i_order_service.dart';

/// Order Service - handles all Order-related Firestore operations
class OrderService implements IOrderService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  OrderService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Get all orders
  @override
  Stream<List<app_models.Order>> getOrders() {
    return _supabase
        .from('orders')
        .order(DatabaseConstants.orderDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => app_models.Order.fromMap(item)).toList());
  }

  /// Get orders by status (interface implementation - accepts String)
  @override
  Stream<List<app_models.Order>> getOrdersByStatus(String status) {
    return _supabase
        .from('orders')
        .eq(DatabaseConstants.status, status)
        .order(DatabaseConstants.orderDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => app_models.Order.fromMap(item)).toList());
  }

  /// Get orders by status enum (legacy method)
  Stream<List<app_models.Order>> getOrdersByStatusEnum(app_models.OrderStatus status) {
    return getOrdersByStatus(status.name);
  }

  /// Get orders by student
  @override
  Stream<List<app_models.Order>> getOrdersByStudent(String studentId) {
    return _supabase
        .from('orders')
        .eq(DatabaseConstants.studentId, studentId)
        .order(DatabaseConstants.orderDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => app_models.Order.fromMap(item)).toList());
  }

  /// Get orders by date range
  @override
  Stream<List<app_models.Order>> getOrdersByDateRange(DateTime start, DateTime end) {
    return _supabase
        .from('orders')
        .gte(DatabaseConstants.orderDate, start.toIso8601String())
        .lte(DatabaseConstants.orderDate, end.toIso8601String())
        .order(DatabaseConstants.orderDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => app_models.Order.fromMap(item)).toList());
  }

  /// Get today's orders
  @override
  Stream<List<app_models.Order>> getTodaysOrders() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getOrdersByDateRange(startOfDay, endOfDay);
  }

  /// Get order by ID
  @override
  Future<app_models.Order?> getOrderById(String id) async {
    final data = await _supabase.from('orders').select().eq('id', id).maybeSingle();
    if (data != null) {
      return app_models.Order.fromMap(data);
    }
    return null;
  }

  /// Create a new order
  @override
  Future<void> createOrder(app_models.Order order) async {
    await _supabase.from('orders').insert(order.toMap());
  }

  /// Update order
  Future<void> updateOrder(app_models.Order order) async {
    await _supabase
        .from('orders')
        .doc(order.id)
        .update(order.toMap());
  }

  /// Update order status (interface implementation - accepts String)
  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final Map<String, dynamic> updateData = {
      DatabaseConstants.status: status,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    };
    await _supabase.from('orders').update(updateData).eq('id', orderId);
  }

  /// Update order status enum (legacy method)
  Future<void> updateOrderStatusEnum(String orderId, app_models.OrderStatus status) async {
    await updateOrderStatus(orderId, status.name);
  }

  /// Cancel an order
  @override
  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, app_models.OrderStatus.cancelled.name);
  }

  /// Delete an order
  @override
  Future<void> deleteOrder(String id) async {
    await _supabase.from('orders').delete().eq('id', id);
  }

  /// Get orders by parent ID
  @override
  Stream<List<app_models.Order>> getOrdersByParent(String parentId) async* {
    // TODO: This requires querying orders by students linked to parent
    // For now, return empty stream
    yield [];
  }

  /// Get today's statistics
  @override
  Future<Map<String, dynamic>> getTodayStatistics() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getOrderStatistics(startOfDay, endOfDay);
  }

  /// Get orders count by date
  @override
  Future<int> getOrdersCountByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final snapshot = await _supabase
        .from('orders')
        .gte(DatabaseConstants.orderDate, startOfDay.toIso8601String())
        .lte(DatabaseConstants.orderDate, endOfDay.toIso8601String())
        .count()
        .get();
    return (data as List).length;
  }

  /// Get total revenue by date
  @override
  Future<double> getTotalRevenueByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final orders = await getOrdersByDateRange(startOfDay, endOfDay).first;
    return orders.fold<double>(0.0, (sum, order) => sum + order.totalAmount);
  }

  /// Get weekly statistics
  @override
  Future<Map<String, dynamic>> getWeeklyStatistics(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return getOrderStatistics(weekStart, weekEnd);
  }

  /// Get monthly statistics
  @override
  Future<Map<String, dynamic>> getMonthlyStatistics(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getOrderStatistics(startOfMonth, endOfMonth);
  }

  /// Update order status (legacy method - accepts enum)
  Future<void> updateOrderStatusLegacy(String orderId, app_models.OrderStatus status) async {
    final Map<String, dynamic> updateData = {
      DatabaseConstants.status: status.name,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    };

    if (status == app_models.OrderStatus.completed) {
      updateData['completedAt'] = DateTime.now().toIso8601String();
    }

    await _supabase.from('orders').update(updateData).eq('id', orderId);
  }

  /// Get order statistics for date range
  Future<Map<String, dynamic>> getOrderStatistics(
      DateTime start, DateTime end) async {
    final snapshot = await _supabase
        .from('orders')
        .gte(DatabaseConstants.orderDate, start.toIso8601String())
        .lte(DatabaseConstants.orderDate, end.toIso8601String())
        .get();

    final orders = data.map((item) => app_models.Order.fromMap(item)).toList();

    double totalRevenue = 0;
    int totalOrders = orders.length;
    int completedOrders = 0;
    int cancelledOrders = 0;

    for (var order in orders) {
      if (order.status == app_models.OrderStatus.completed) {
        totalRevenue += order.totalAmount;
        completedOrders++;
      } else if (order.status == app_models.OrderStatus.cancelled) {
        cancelledOrders++;
      }
    }

    return {
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'pendingOrders': totalOrders - completedOrders - cancelledOrders,
      'totalRevenue': totalRevenue,
      // averageOrderValue should be computed over completed orders only
      'averageOrderValue': completedOrders > 0 ? totalRevenue / completedOrders : 0,
    };
  }
}
