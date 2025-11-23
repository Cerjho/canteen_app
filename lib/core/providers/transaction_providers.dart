import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/i_order_service.dart';
import '../interfaces/i_topup_service.dart';
import '../services/order_service.dart';
import '../services/topup_service.dart';
import '../services/parent_service.dart';
import '../models/order.dart' as order_model;
import '../models/topup.dart';
import '../models/parent_transaction.dart';
import 'supabase_providers.dart';
import 'date_refresh_provider.dart';
import 'auth_providers.dart';

// ============================================================================
// ORDER & TOPUP SERVICE PROVIDERS
// ============================================================================

/// Order Service Provider
/// 
/// Handles order management (CRUD, status updates, statistics).
final orderServiceProvider = Provider<IOrderService>((ref) {
  return OrderService(
    supabase: ref.watch(supabaseProvider),
  );
});

/// Topup Service Provider
/// 
/// Handles top-up request management (approval, rejection, statistics).
final topupServiceProvider = Provider<ITopupService>((ref) {
  return TopupService(
    supabase: ref.watch(supabaseProvider),
  );
});

// ============================================================================
// ORDER DATA PROVIDERS
// ============================================================================

/// All Orders Provider
/// 
/// Streams all orders in the system (admin view).
/// Returns: Stream<List<Order>>
final ordersProvider = StreamProvider((ref) {
  return ref.watch(orderServiceProvider).getOrders();
});

/// Today's Orders Provider
/// 
/// Streams orders placed today.
/// Returns: Stream<List<Order>>
final todaysOrdersProvider = StreamProvider((ref) {
  // Recreate the stream when the app-level "today" changes so UI updates after midnight/resume
  ref.watch(dateRefreshProvider);
  return ref.watch(orderServiceProvider).getTodaysOrders();
});

/// Pending Orders Provider
/// 
/// Streams orders with pending status.
/// Returns: Stream<List<Order>>
final pendingOrdersProvider = StreamProvider((ref) {
  return ref.watch(orderServiceProvider).getOrdersByStatus('pending');
});

/// Completed Orders Provider
/// 
/// Streams orders with completed status.
/// Returns: Stream<List<Order>>
final completedOrdersProvider = StreamProvider((ref) {
  return ref.watch(orderServiceProvider).getOrdersByStatus('completed');
});

// ============================================================================
// TOPUP DATA PROVIDERS
// ============================================================================

/// All Topups Provider
/// 
/// Streams all top-up requests in the system (admin view).
/// Returns: Stream<List<Topup>>
final topupsProvider = StreamProvider((ref) {
  return ref.watch(topupServiceProvider).getTopups();
});

/// Pending Topups Provider
/// 
/// Streams top-up requests with pending status.
/// Returns: Stream<List<Topup>>
final pendingTopupsProvider = StreamProvider((ref) {
  return ref.watch(topupServiceProvider).getPendingTopups();
});

/// Approved Topups Provider
/// 
/// Streams top-up requests with approved status.
/// Returns: Stream<List<Topup>>
final approvedTopupsProvider = StreamProvider((ref) {
  return ref.watch(topupServiceProvider).getApprovedTopups();
});

/// Declined Topups Provider
/// 
/// Streams top-up requests with declined status.
/// Returns: Stream<List<Topup>>
final declinedTopupsProvider = StreamProvider((ref) {
  return ref.watch(topupServiceProvider).getRejectedTopups();
});

// ============================================================================
// STATISTICS PROVIDERS
// ============================================================================

/// Today's Statistics Provider
/// 
/// Fetches order statistics for today.
/// Returns: Future<Map<String, dynamic>>
final todayStatsProvider = FutureProvider((ref) {
  // Recompute when the app-level "today" changes
  ref.watch(dateRefreshProvider);
  return ref.watch(orderServiceProvider).getTodayStatistics();
});

/// Weekly Statistics Provider
/// 
/// Fetches order statistics for the current week.
/// Returns: Future<Map<String, dynamic>>
final weeklyStatsProvider = FutureProvider((ref) {
  final now = ref.watch(dateRefreshProvider);
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return ref.watch(orderServiceProvider).getWeeklyStatistics(monday);
});

/// Monthly Statistics Provider
/// 
/// Fetches order statistics for the current month.
/// Returns: Future<Map<String, dynamic>>
final monthlyStatsProvider = FutureProvider((ref) {
  final now = ref.watch(dateRefreshProvider);
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  return ref.watch(orderServiceProvider).getMonthlyStatistics(firstDayOfMonth);
});

/// Pending Topups Count Provider
/// 
/// Fetches count of pending top-up requests today.
/// Returns: Future<int>
final pendingTopupsCountProvider = FutureProvider((ref) {
  return ref.watch(topupServiceProvider).getTodayPendingCount();
});

/// Total Pending Amount Provider
/// 
/// Fetches total amount of all pending top-up requests.
/// Returns: Future<double>
final totalPendingAmountProvider = FutureProvider((ref) {
  return ref.watch(topupServiceProvider).getTotalPendingAmount();
});

// ============================================================================
// FAMILY PROVIDERS
// ============================================================================

/// Student Orders Provider Family
/// 
/// Streams orders for a specific student.
/// Usage: ref.watch(studentOrdersProvider(studentId))
/// Returns: Stream<List<Order>>
final studentOrdersProvider = StreamProvider.family<List<order_model.Order>, String>((ref, studentId) {
  return ref.watch(orderServiceProvider).getOrdersByStudent(studentId);
});

/// Parent Orders Provider Family
/// 
/// Streams orders for a specific parent (all linked students).
/// Usage: ref.watch(parentOrdersProviderFamily(parentId))
/// Returns: Stream<List<Order>>
final parentOrdersProviderFamily = StreamProvider.family<List<order_model.Order>, String>((ref, parentId) {
  return ref.watch(orderServiceProvider).getOrdersByParent(parentId);
});

/// Parent Orders Provider (Current User)
/// 
/// Streams orders for the currently signed-in parent (all linked students).
/// Returns: Stream<List<Order>>
final parentOrdersProvider = StreamProvider<List<order_model.Order>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return const Stream.empty();
  return ref.watch(orderServiceProvider).getOrdersByParent(currentUser.uid);
});

/// Order by ID Provider Family
/// 
/// Streams a specific order by ID.
/// Usage: ref.watch(orderByIdProvider(orderId))
/// Returns: Stream<Order?>
/// 
/// Note: Interface doesn't expose getOrderStream, so we filter from all orders.
/// Consider adding getOrderById to the interface if direct stream access is needed.
final orderByIdProvider = StreamProvider.family<order_model.Order?, String>((ref, orderId) async* {
  await for (final orders in ref.watch(orderServiceProvider).getOrders()) {
    final order = orders.where((o) => o.id == orderId).firstOrNull;
    yield order;
  }
});

/// Topup by ID Provider Family
/// 
/// Streams a specific top-up request by ID.
/// Usage: ref.watch(topupByIdProvider(topupId))
/// Returns: Stream<Topup?>
/// 
/// Note: Interface doesn't expose getTopupStream, so we filter from all topups.
/// Consider adding getTopupById to the interface if direct stream access is needed.
final topupByIdProvider = StreamProvider.family<Topup?, String>((ref, topupId) async* {
  await for (final topups in ref.watch(topupServiceProvider).getTopups()) {
    final topup = topups.where((t) => t.id == topupId).firstOrNull;
    yield topup;
  }
});

/// Parent Topups Provider Family
/// 
/// Streams top-up requests for a specific parent.
/// Usage: ref.watch(parentTopupsProvider(parentId))
/// Returns: Stream<List<Topup>>
final parentTopupsProviderFamily = StreamProvider.family<List<Topup>, String>((ref, parentId) {
  return ref.watch(topupServiceProvider).getTopupsByParent(parentId);
});

// ============================================================================
// PARENT TRANSACTION PROVIDERS
// ============================================================================

/// Parent Service Provider (for transactions)
final parentServiceForTransactionsProvider = Provider<ParentService>((ref) {
  return ParentService(
    supabase: ref.watch(supabaseProvider),
  );
});

/// Parent Transactions Stream Provider Family
/// 
/// Streams all transactions for a specific parent, ordered by created_at descending.
/// Usage: ref.watch(parentTransactionsStreamProvider(parentId))
/// Returns: Stream<List<ParentTransaction>>
final parentTransactionsStreamProvider = StreamProvider.family<List<ParentTransaction>, String>((ref, parentId) {
  return ref.watch(parentServiceForTransactionsProvider).getParentTransactionsStream(parentId);
});
