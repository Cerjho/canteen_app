import '../models/order.dart';

/// Interface for Order Service operations
/// 
/// This interface defines the contract for order-related operations.
abstract class IOrderService {
  /// Get all orders as a stream
  Stream<List<Order>> getOrders();

  /// Get today's orders
  Stream<List<Order>> getTodaysOrders();

  /// Get orders by student ID
  Stream<List<Order>> getOrdersByStudent(String studentId);

  /// Get orders by parent ID
  Stream<List<Order>> getOrdersByParent(String parentId);

  /// Get orders by status
  Stream<List<Order>> getOrdersByStatus(String status);

  /// Get orders by date range
  Stream<List<Order>> getOrdersByDateRange(DateTime startDate, DateTime endDate);

  /// Get order by ID
  Future<Order?> getOrderById(String id);

  /// Create a new order
  Future<void> createOrder(Order order);

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status);

  /// Cancel an order
  Future<void> cancelOrder(String orderId);

  /// Delete an order
  Future<void> deleteOrder(String id);

  /// Get today's statistics
  Future<Map<String, dynamic>> getTodayStatistics();

  /// Get orders count by date
  Future<int> getOrdersCountByDate(DateTime date);

  /// Get total revenue by date
  Future<double> getTotalRevenueByDate(DateTime date);

  /// Get weekly statistics
  Future<Map<String, dynamic>> getWeeklyStatistics(DateTime weekStart);

  /// Get monthly statistics
  Future<Map<String, dynamic>> getMonthlyStatistics(DateTime month);
}
