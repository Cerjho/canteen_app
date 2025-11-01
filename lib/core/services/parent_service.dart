import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parent.dart';
import '../constants/database_constants.dart';
import '../interfaces/i_parent_service.dart';
import 'user_service.dart';

/// Parent Service - handles all Parent-related Firestore operations
/// 
/// This service manages the `parents` collection which stores parent-specific data
/// separate from the base user account in the `users` collection.
/// 
/// **Collection Structure:**
///
/// parents/{userId} -> {
///   userId: string,      // References users/{userId}
///   balance: number,
///   address: string,
///   phone: string,
///   children: string[],  // Array of student IDs
///   createdAt: Timestamp,
///   updatedAt: Timestamp
/// }
///
/// 
/// **Key Design Decisions:**
/// - Document ID matches the user's UID from Firebase Auth and users collection
/// - Parent-specific data (balance, address, phone) is separate from user account
/// - Use `UserService` to get user's name and email
/// - Use `RegistrationService.registerParent()` to create new parents atomically
class ParentService implements IParentService {
  final SupabaseClient _supabase;
  final UserService _userService;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  /// [userService] - Optional UserService instance for testing
  ParentService({
    SupabaseClient? supabase,
    UserService? userService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _userService = userService ?? UserService();

  /// Get all parents
  /// 
  /// Note: This returns Parent objects without user info (name, email).
  /// To get full parent details, combine with UserService.getUser()
  @override
  Stream<List<Parent>> getParents() {
    return _supabase
        .from('parents')
        .order(DatabaseConstants.createdAt, ascending: false)
        .snapshots()
        .map((data) =>
            data.map((item) => Parent.fromMap(item)).toList());
  }

  /// Get parent by ID (userId)
  /// 
  /// Returns the parent document. To get user info (name, email),
  /// use `UserService.getUser(parent.userId)`.
  @override
  Future<Parent?> getParentById(String userId) async {
    final data = await _supabase.from('parents').select().eq('id', userId).maybeSingle();
    if (data != null) {
      return Parent.fromMap(data);
    }
    return null;
  }

  /// Get parent by ID as a stream (real-time updates)
  /// 
  /// Returns a stream of parent document updates. Useful for watching
  /// real-time changes to parent profile (balance, photo, etc.).
  @override
  Stream<Parent?> getParentStream(String userId) {
    return _supabase
        .from('parents')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (data != null) {
        return Parent.fromMap(data);
      }
      return null;
    });
  }

  /// Get parent by user email
  /// 
  /// This requires looking up the user first to get their userId,
  /// then fetching the parent document.
  Future<Parent?> getParentByEmail(String email) async {
    // First, find the user by email in users collection
    final user = await _userService.getUserByEmail(email);
    if (user == null || !user.isParent) {
      return null;
    }

    // Then fetch parent document using user's UID
    return getParentById(user.uid);
  }

  /// Get parent with user info
  /// 
  /// Returns a map containing both parent and user data.
  /// This is useful when you need full parent details including name/email.
  Future<Map<String, dynamic>?> getParentWithUserInfo(String userId) async {
    final parent = await getParentById(userId);
    if (parent == null) return null;

    final user = await _userService.getUser(userId);
    if (user == null) return null;

    return {
      'parent': parent,
      'user': user,
    };
  }

  /// Create a new parent
  /// 
  /// ⚠️ WARNING: This only creates the parent document.
  /// Use `RegistrationService.registerParent()` instead to create
  /// both the user account and parent document atomically.
  Future<void> createParent(Parent parent) async {
    await _supabase.from('parents').insert(parent.toMap());
  }

  /// Add a new parent (interface implementation)
  @override
  Future<void> addParent(Parent parent) async {
    await createParent(parent);
  }

  /// Update parent
  /// 
  /// Updates parent-specific fields (address, phone, etc.).
  /// To update user info (name, email), use UserService.
  @override
  Future<void> updateParent(Parent parent) async {
    final updatedParent = parent.copyWith(updatedAt: DateTime.now());
    await _supabase
        .from('parents')
        .doc(parent.userId)
        .update(updatedParent.toMap());
  }

  /// Update parent contact information
  /// 
  /// Convenience method to update address and/or phone.
  Future<void> updateContactInfo({
    required String userId,
    String? address,
    String? phone,
  }) async {
    final updates = <String, dynamic>{
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
    };

    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;

    await _supabase.from('parents').update(updates).eq('id', userId);
  }

  /// Delete parent
  /// 
  /// ⚠️ WARNING: This only deletes the parent document.
  /// Consider also deleting:
  /// - User document in users collection
  /// - Firebase Auth account
  /// - Unlinking all students
  @override
  Future<void> deleteParent(String userId) async {
    await _supabase.from('parents').delete().eq('id', userId);
  }

  /// Update parent balance
  /// 
  /// Used for top-ups and deductions.
  @override
  Future<void> updateBalance(String userId, double newBalance) async {
    await _supabase.from('parents').update({
      DatabaseConstants.balance: newBalance,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String().eq('id', userId),
    });
  }

  /// Add to parent balance
  @override
  Future<void> addBalance(String userId, double amount) async {
    final parent = await getParentById(userId);
    if (parent != null) {
      final newBalance = parent.balance + amount;
      await updateBalance(userId, newBalance);
    }
  }

  /// Deduct from parent balance
  @override
  Future<void> deductBalance(String userId, double amount) async {
    final parent = await getParentById(userId);
    if (parent != null) {
      final newBalance = parent.balance - amount;
      await updateBalance(userId, newBalance);
    }
  }

  /// Add amount to parent balance
  /// 
  /// Increments the balance by the specified amount.
  /// Use negative amounts for deductions.
  Future<void> adjustBalance(String userId, double amount) async {
    final parent = await getParentById(userId);
    if (parent != null) {
      final newBalance = parent.balance + amount;
      await updateBalance(userId, newBalance);
    }
  }

  /// Add student to parent's children array
  /// 
  /// ⚠️ Use `RegistrationService.linkStudentToParent()` instead.
  /// This method only updates the parent's children array and does not
  /// update the student's parentId field atomically.
  Future<void> addStudent(String userId, String studentId) async {
    final parent = await getParentById(userId);
    if (parent != null) {
      // Prevent duplicates
      if (parent.children.contains(studentId)) {
        return;
      }
      
      final updatedChildren = [...parent.children, studentId];
      await _supabase.from('parents').update({
        'children': updatedChildren,
        DatabaseConstants.updatedAt: DateTime.now().toIso8601String().eq('id', userId),
      });
    }
  }

  /// Remove student from parent's children array
  /// 
  /// ⚠️ Use `RegistrationService.unlinkStudentFromParent()` instead.
  /// This method only updates the parent's children array and does not
  /// update the student's parentId field atomically.
  Future<void> removeStudent(String userId, String studentId) async {
    final parent = await getParentById(userId);
    if (parent != null) {
      final updatedChildren = parent.children.where((id) => id != studentId).toList();
      await _supabase.from('parents').update({
        'children': updatedChildren,
        DatabaseConstants.updatedAt: DateTime.now().toIso8601String().eq('id', userId),
      });
    }
  }

  /// Record a parent transaction inside an existing Firestore transaction
  ///
  /// This helper writes a document to `parent_transactions` collection containing
  /// details of the balance adjustment. It must be invoked inside a Firestore
  /// transaction so it can be atomically committed alongside other updates.
  Future<void> recordTransactionInTx({
    required Transaction tx,
    required String parentId,
    required double amount,
    required double balanceBefore,
    required double balanceAfter,
    required List<String> orderIds,
    required String reason,
  }) async {
    final transactionsRef = _supabase.from('parent_transactions');
    final txDoc = transactionsRef.doc();
    final payload = {
      'parentId': parentId,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'orderIds': orderIds,
      'reason': reason,
      DatabaseConstants.createdAt: DateTime.now().toIso8601String(),
    };

    tx.set(txDoc, payload);
  }

  /// Link student to parent (interface implementation)
  @override
  Future<void> linkStudent(String parentId, String studentId) async {
    await addStudent(parentId, studentId);
  }

  /// Unlink student from parent (interface implementation)
  @override
  Future<void> unlinkStudent(String parentId, String studentId) async {
    await removeStudent(parentId, studentId);
  }

  /// Search parents by name, email, phone, or address
  /// 
  /// Returns a stream of parents matching the search query.
  /// This is a client-side filter operation and may be slow for large datasets.
  @override
  Stream<List<Parent>> searchParents(String query) {
    return _supabase
        .from('parents')
        .snapshots()
        .map((snapshot) {
      final lowercaseQuery = query.toLowerCase();
      return data
          .map((doc) => Parent.fromMap(item))
          .where((parent) =>
              (parent.phone?.toLowerCase().contains(lowercaseQuery) ?? false) ||
              (parent.address?.toLowerCase().contains(lowercaseQuery) ?? false))
          .toList();
    });
  }

  /// Search parents by name, email, phone, or address (legacy method)
  /// 
  /// Note: Searching by name/email requires loading users collection data.
  /// This is a client-side filter operation and may be slow for large datasets.
  /// Consider using Algolia or similar for production search.
  Future<List<Map<String, dynamic>>> searchParentsWithUser(String query) async {
    final lowercaseQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];

    // Get all parents
    final parentsSnapshot = await _supabase.from('parents').get();
    
    for (final parentDoc in parentsdata) {
      final parent = Parent.fromMap(parentdata);
      
      // Check if phone or address matches
      final phoneMatch = parent.phone?.toLowerCase().contains(lowercaseQuery) ?? false;
      final addressMatch = parent.address?.toLowerCase().contains(lowercaseQuery) ?? false;
      
      if (phoneMatch || addressMatch) {
        // Get user info for this parent
        final user = await _userService.getUser(parent.userId);
        results.add({
          'parent': parent,
          'user': user,
        });
        continue;
      }

      // Check if name or email matches (requires fetching user)
      final user = await _userService.getUser(parent.userId);
      if (user != null) {
        final nameMatch = user.name.toLowerCase().contains(lowercaseQuery);
        final emailMatch = user.email.toLowerCase().contains(lowercaseQuery);
        
        if (nameMatch || emailMatch) {
          results.add({
            'parent': parent,
            'user': user,
          });
        }
      }
    }

    return results;
  }

  /// Get parents count
  Future<int> getParentsCount() async {
    final snapshot = await _supabase.from('parents').select('id');
    return (data as List).length;
  }

  /// Get parents with low balance
  /// 
  /// Returns parents whose balance is below the specified threshold.
  Future<List<Parent>> getParentsWithLowBalance(double threshold) async {
    final snapshot = await _supabase
        .from('parents')
        .lt(DatabaseConstants.balance, threshold)
        .get();

    return data
        .map((doc) => Parent.fromMap(item))
        .toList();
  }

  /// Get parents with specific student
  /// 
  /// Returns all parents who have the specified student in their children array.
  Future<List<Parent>> getParentsByStudent(String studentId) async {
    final snapshot = await _supabase
        .from('parents')
        .contains('children', [studentId])
        .get();

    return data
        .map((doc) => Parent.fromMap(item))
        .toList();
  }

  /// Import parents from CSV
  /// 
  /// This is a stub implementation. Full CSV import functionality
  /// should be implemented based on business requirements.
  @override
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes) async {
    // TODO: Implement CSV import for parents
    throw UnimplementedError('Parent CSV import not yet implemented');
  }

  /// Export parents to CSV
  /// 
  /// This is a stub implementation. Full CSV export functionality
  /// should be implemented based on business requirements.
  @override
  Future<List<int>> exportToCSV() async {
    // TODO: Implement CSV export for parents
    throw UnimplementedError('Parent CSV export not yet implemented');
  }

  /// Import parents from Excel
  /// 
  /// This is a stub implementation. Full Excel import functionality
  /// should be implemented based on business requirements.
  @override
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes) async {
    // TODO: Implement Excel import for parents
    throw UnimplementedError('Parent Excel import not yet implemented');
  }

  /// Export parents to Excel
  /// 
  /// This is a stub implementation. Full Excel export functionality
  /// should be implemented based on business requirements.
  @override
  Future<List<int>> exportToExcel() async {
    // TODO: Implement Excel export for parents
    throw UnimplementedError('Parent Excel export not yet implemented');
  }
}
