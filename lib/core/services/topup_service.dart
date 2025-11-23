import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';
import '../models/topup.dart';
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
        .from('topup_requests')
        .stream(primaryKey: ['id'])
        .order('request_date', ascending: false)
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get top-ups by status
  Stream<List<Topup>> getTopupsByStatus(TopupStatus status) {
    return _supabase
        .from('topup_requests')
        .stream(primaryKey: ['id'])
        .eq('status', status.name)
        .order('request_date', ascending: false)
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
        .from('topup_requests')
        .stream(primaryKey: ['id'])
        .eq('parent_id', parentId)
        .order('request_date', ascending: false)
        .map((data) =>
            data.map((item) => Topup.fromMap(item)).toList());
  }

  /// Get top-up by ID
  @override
  Future<Topup?> getTopupById(String id) async {
    final data = await _supabase.from('topup_requests').select().eq('id', id).maybeSingle();
    if (data != null) {
      return Topup.fromMap(data);
    }
    return null;
  }

  /// Create a new top-up request
  @override
  Future<void> createTopup(Topup topup) async {
    // If a backend API is configured, call it; otherwise write directly to Supabase
    if (apiClient.enabled) {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('User not authenticated');
      final token = session.accessToken;
      final res = await apiClient.post('/parent/topup', headers: {'Authorization': 'Bearer $token'}, body: topup.toMap());
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw Exception('Failed to create topup: ${res.statusCode} ${res.body}');
      }
      return;
    }

    await _supabase.from('topup_requests').insert(topup.toMap());
  }

  /// Update top-up
  Future<void> updateTopup(Topup topup) async {
    await _supabase
        .from('topup_requests')
        .update(topup.toMap())
        .eq('id', topup.id);
  }

  /// Approve top-up (interface implementation)
  @override
  Future<void> approveTopup(String topupId, String approvedBy) async {
    await _supabase.from('topup_requests').update({
      'status': TopupStatus.approved.name,
      'processed_by': approvedBy,
      'processed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', topupId);
  }

  /// Approve top-up with notes (extended version)
  Future<void> approveTopupWithNotes(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _supabase.from('topup_requests').update({
      'status': TopupStatus.approved.name,
      'processed_by': adminId,
      'processed_at': DateTime.now().toIso8601String(),
      'admin_notes': adminNotes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', topupId);
  }

  /// Reject top-up (interface implementation)
  @override
  Future<void> rejectTopup(String topupId, String rejectedBy, String reason) async {
    await _supabase.from('topup_requests').update({
      'status': TopupStatus.declined.name,
      'processed_by': rejectedBy,
      'processed_at': DateTime.now().toIso8601String(),
      'admin_notes': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', topupId);
  }

  /// Decline top-up (legacy method)
  Future<void> declineTopup(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _supabase.from('topup_requests').update({
      'status': TopupStatus.declined.name,
      'processed_by': adminId,
      'processed_at': DateTime.now().toIso8601String(),
      'admin_notes': adminNotes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', topupId);
  }

  /// Complete top-up (mark as completed after balance update)
  Future<void> completeTopup(String topupId) async {
    await _supabase.from('topup_requests').update({
      'status': TopupStatus.completed.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', topupId);
  }

  /// Delete a top-up request
  @override
  Future<void> deleteTopup(String id) async {
    await _supabase.from('topup_requests').delete().eq('id', id);
  }

  /// Get today's pending top-ups count
  @override
  Future<int> getTodayPendingCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final data = await _supabase
        .from('topup_requests')
        .select('id')
        .eq('status', TopupStatus.pending.name)
        .gte('request_date', startOfDay.toIso8601String())
        .lte('request_date', endOfDay.toIso8601String());
    
    return (data as List).length;
  }

  /// Get total pending amount
  @override
  Future<double> getTotalPendingAmount() async {
    final data = await _supabase
        .from('topup_requests')
        .select()
        .eq('status', TopupStatus.pending.name);
    
    final topups = (data as List).map((item) => Topup.fromMap(item)).toList();
    return topups.fold<double>(0.0, (sum, topup) => sum + topup.amount);
  }

  /// Get top-ups by date range
  @override
  Stream<List<Topup>> getTopupsByDateRange(DateTime startDate, DateTime endDate) {
    return _supabase
        .from('topup_requests')
        .stream(primaryKey: ['id'])
        .gte('request_date', startDate.toIso8601String())
        .order('request_date', ascending: false)
        .map((data) => data
            .map((item) => Topup.fromMap(item))
            .where((topup) => topup.requestDate.isBefore(endDate) || topup.requestDate.isAtSameMomentAs(endDate))
            .toList());
  }

  /// Get top-up statistics for date range
  Future<Map<String, dynamic>> getTopupStatistics(
      DateTime start, DateTime end) async {
    final data = await _supabase
        .from('topup_requests')
        .select()
        .gte('request_date', start.toIso8601String())
        .lte('request_date', end.toIso8601String());

    final topups = (data as List).map((item) => Topup.fromMap(item)).toList();

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
