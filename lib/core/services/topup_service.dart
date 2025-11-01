import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_client.dart';
import '../models/topup.dart';
import '../constants/database_constants.dart';
import '../interfaces/i_topup_service.dart';

/// Topup Service - handles all Topup-related Firestore operations
class TopupService implements ITopupService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  TopupService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Get all top-ups
  @override
  Stream<List<Topup>> getTopups() {
    return _supabase
        .from('topups')
        .order(DatabaseConstants.requestDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get top-ups by status
  Stream<List<Topup>> getTopupsByStatus(TopupStatus status) {
    return _supabase
        .from('topups')
        .eq(DatabaseConstants.status, status.name)
        .order(DatabaseConstants.requestDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get pending top-ups
  @override
  Stream<List<Topup>> getPendingTopups() {
    return getTopupsByStatus(TopupStatus.pending);
  }

  /// Get approved top-ups
  @override
  Stream<List<Topup>> getApprovedTopups() {
    return getTopupsByStatus(TopupStatus.approved);
  }

  /// Get rejected top-ups
  @override
  Stream<List<Topup>> getRejectedTopups() {
    return getTopupsByStatus(TopupStatus.declined);
  }

  /// Get top-ups by parent
  @override
  Stream<List<Topup>> getTopupsByParent(String parentId) {
    return _supabase
        .from('topups')
        .eq(DatabaseConstants.parentId, parentId)
        .order(DatabaseConstants.requestDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get top-up by ID
  @override
  Future<Topup?> getTopupById(String id) async {
    final data = await _supabase.from('topups').select().eq('id', id).maybeSingle();
    if (data != null) {
      return Topup.fromMap(data);
    }
    return null;
  }

  /// Create a new top-up request
  @override
  Future<void> createTopup(Topup topup) async {
    // If a backend API is configured, call it; otherwise write directly to Firestore
    if (apiClient.enabled) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('User not authenticated');
      final res = await apiClient.post('/parent/topup', headers: {'Authorization': 'Bearer $token'}, body: topup.toMap());
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('Failed to create topup: ${res.statusCode} ${res.body}');
      }
      return;
    }

    await _supabase.from('topups').insert(topup.toMap());
  }

  /// Update top-up
  Future<void> updateTopup(Topup topup) async {
    await _supabase
        .from('topups')
        .doc(topup.id)
        .update(topup.toMap());
  }

  /// Approve top-up (interface implementation)
  @override
  Future<void> approveTopup(String topupId, String approvedBy) async {
    await _supabase.from('topups').update({
      DatabaseConstants.status: TopupStatus.approved.name,
      'processedBy': approvedBy,
      'processedAt': DateTime.now().toIso8601String().eq('id', topupId),
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Approve top-up with notes (extended version)
  Future<void> approveTopupWithNotes(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _supabase.from('topups').update({
      DatabaseConstants.status: TopupStatus.approved.name,
      'processedBy': adminId,
      'processedAt': DateTime.now().toIso8601String().eq('id', topupId),
      'adminNotes': adminNotes,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Reject top-up (interface implementation)
  @override
  Future<void> rejectTopup(String topupId, String rejectedBy, String reason) async {
    await _supabase.from('topups').update({
      DatabaseConstants.status: TopupStatus.declined.name,
      'processedBy': rejectedBy,
      'processedAt': DateTime.now().toIso8601String().eq('id', topupId),
      'adminNotes': reason,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Decline top-up (legacy method)
  Future<void> declineTopup(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _supabase.from('topups').update({
      DatabaseConstants.status: TopupStatus.declined.name,
      'processedBy': adminId,
      'processedAt': DateTime.now().toIso8601String().eq('id', topupId),
      'adminNotes': adminNotes,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Complete top-up (mark as completed after balance update)
  Future<void> completeTopup(String topupId) async {
    await _supabase.from('topups').update({
      DatabaseConstants.status: TopupStatus.completed.name,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String().eq('id', topupId),
    });
  }

  /// Delete a top-up request
  @override
  Future<void> deleteTopup(String id) async {
    await _supabase.from('topups').delete().eq('id', id);
  }

  /// Get today's pending top-ups count
  @override
  Future<int> getTodayPendingCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final snapshot = await _supabase
        .from('topups')
        .eq(DatabaseConstants.status, TopupStatus.pending.name)
        .gte(DatabaseConstants.requestDate, startOfDay.toIso8601String())
        .lte(DatabaseConstants.requestDate, endOfDay.toIso8601String())
        .count()
        .get();
    
    return (data as List).length;
  }

  /// Get total pending amount
  @override
  Future<double> getTotalPendingAmount() async {
    final snapshot = await _supabase
        .from('topups')
        .eq(DatabaseConstants.status, TopupStatus.pending.name)
        .get();
    
    final topups = data.map((item) => Topup.fromMap(item)).toList();
    return topups.fold<double>(0.0, (sum, topup) => sum + topup.amount);
  }

  /// Get top-ups by date range
  @override
  Stream<List<Topup>> getTopupsByDateRange(DateTime startDate, DateTime endDate) {
    return _supabase
        .from('topups')
        .gte(DatabaseConstants.requestDate, startDate.toIso8601String())
        .lte(DatabaseConstants.requestDate, endDate.toIso8601String())
        .order(DatabaseConstants.requestDate, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get top-up statistics for date range
  Future<Map<String, dynamic>> getTopupStatistics(
      DateTime start, DateTime end) async {
    final snapshot = await _supabase
        .from('topups')
        .gte(DatabaseConstants.requestDate, start.toIso8601String())
        .lte(DatabaseConstants.requestDate, end.toIso8601String())
        .get();

    final topups = data.map((item) => Topup.fromMap(item)).toList();

    double totalAmount = 0;
    double approvedAmount = 0;
    int totalRequests = topups.length;
    int pendingRequests = 0;
    int approvedRequests = 0;
    int declinedRequests = 0;

    for (var topup in topups) {
      totalAmount += topup.amount;
      
      switch (topup.status) {
        case TopupStatus.pending:
          pendingRequests++;
          break;
        case TopupStatus.approved:
        case TopupStatus.completed:
          approvedRequests++;
          approvedAmount += topup.amount;
          break;
        case TopupStatus.declined:
          declinedRequests++;
          break;
      }
    }

    return {
      'totalRequests': totalRequests,
      'pendingRequests': pendingRequests,
      'approvedRequests': approvedRequests,
      'declinedRequests': declinedRequests,
      'totalAmount': totalAmount,
      'approvedAmount': approvedAmount,
    };
  }
}
