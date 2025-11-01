import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_client.dart';
import '../models/topup.dart';
import '../constants/firestore_constants.dart';
import '../interfaces/i_topup_service.dart';

/// Topup Service - handles all Topup-related Firestore operations
class TopupService implements ITopupService {
  final FirebaseFirestore _firestore;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  TopupService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all top-ups
  @override
  Stream<List<Topup>> getTopups() {
    return _firestore
        .collection(FirestoreConstants.topupsCollection)
        .orderBy(FirestoreConstants.requestDate, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList());
  }

  /// Get top-ups by status
  Stream<List<Topup>> getTopupsByStatus(TopupStatus status) {
    return _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.status, isEqualTo: status.name)
        .orderBy(FirestoreConstants.requestDate, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList());
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
    return _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.parentId, isEqualTo: parentId)
        .orderBy(FirestoreConstants.requestDate, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList());
  }

  /// Get top-up by ID
  @override
  Future<Topup?> getTopupById(String id) async {
    final doc = await _firestore.collection(FirestoreConstants.topupsCollection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Topup.fromMap(doc.data()!);
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

    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topup.id).set(topup.toMap());
  }

  /// Update top-up
  Future<void> updateTopup(Topup topup) async {
    await _firestore
        .collection(FirestoreConstants.topupsCollection)
        .doc(topup.id)
        .update(topup.toMap());
  }

  /// Approve top-up (interface implementation)
  @override
  Future<void> approveTopup(String topupId, String approvedBy) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topupId).update({
      FirestoreConstants.status: TopupStatus.approved.name,
      'processedBy': approvedBy,
      'processedAt': Timestamp.now(),
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Approve top-up with notes (extended version)
  Future<void> approveTopupWithNotes(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topupId).update({
      FirestoreConstants.status: TopupStatus.approved.name,
      'processedBy': adminId,
      'processedAt': Timestamp.now(),
      'adminNotes': adminNotes,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Reject top-up (interface implementation)
  @override
  Future<void> rejectTopup(String topupId, String rejectedBy, String reason) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topupId).update({
      FirestoreConstants.status: TopupStatus.declined.name,
      'processedBy': rejectedBy,
      'processedAt': Timestamp.now(),
      'adminNotes': reason,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Decline top-up (legacy method)
  Future<void> declineTopup(
    String topupId,
    String adminId, {
    String? adminNotes,
  }) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topupId).update({
      FirestoreConstants.status: TopupStatus.declined.name,
      'processedBy': adminId,
      'processedAt': Timestamp.now(),
      'adminNotes': adminNotes,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Complete top-up (mark as completed after balance update)
  Future<void> completeTopup(String topupId) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(topupId).update({
      FirestoreConstants.status: TopupStatus.completed.name,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Delete a top-up request
  @override
  Future<void> deleteTopup(String id) async {
    await _firestore.collection(FirestoreConstants.topupsCollection).doc(id).delete();
  }

  /// Get today's pending top-ups count
  @override
  Future<int> getTodayPendingCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final snapshot = await _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.status, isEqualTo: TopupStatus.pending.name)
        .where(FirestoreConstants.requestDate, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where(FirestoreConstants.requestDate, isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  /// Get total pending amount
  @override
  Future<double> getTotalPendingAmount() async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.status, isEqualTo: TopupStatus.pending.name)
        .get();
    
    final topups = snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList();
    return topups.fold<double>(0.0, (sum, topup) => sum + topup.amount);
  }

  /// Get top-ups by date range
  @override
  Stream<List<Topup>> getTopupsByDateRange(DateTime startDate, DateTime endDate) {
    return _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.requestDate, isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where(FirestoreConstants.requestDate, isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy(FirestoreConstants.requestDate, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList());
  }

  /// Get top-up statistics for date range
  Future<Map<String, dynamic>> getTopupStatistics(
      DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.topupsCollection)
        .where(FirestoreConstants.requestDate, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where(FirestoreConstants.requestDate, isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final topups = snapshot.docs.map((doc) => Topup.fromMap(doc.data())).toList();

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
