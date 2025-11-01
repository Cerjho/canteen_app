import '../models/topup.dart';

/// Interface for Top-up Service operations
/// 
/// This interface defines the contract for top-up request operations.
abstract class ITopupService {
  /// Get all top-up requests as a stream
  Stream<List<Topup>> getTopups();

  /// Get pending top-up requests
  Stream<List<Topup>> getPendingTopups();

  /// Get approved top-up requests
  Stream<List<Topup>> getApprovedTopups();

  /// Get rejected top-up requests
  Stream<List<Topup>> getRejectedTopups();

  /// Get top-ups by parent ID
  Stream<List<Topup>> getTopupsByParent(String parentId);

  /// Get top-up by ID
  Future<Topup?> getTopupById(String id);

  /// Create a new top-up request
  Future<void> createTopup(Topup topup);

  /// Approve a top-up request
  Future<void> approveTopup(String topupId, String approvedBy);

  /// Reject a top-up request
  Future<void> rejectTopup(String topupId, String rejectedBy, String reason);

  /// Delete a top-up request
  Future<void> deleteTopup(String id);

  /// Get today's pending top-ups count
  Future<int> getTodayPendingCount();

  /// Get total pending amount
  Future<double> getTotalPendingAmount();

  /// Get top-ups by date range
  Stream<List<Topup>> getTopupsByDateRange(DateTime startDate, DateTime endDate);
}
