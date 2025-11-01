import '../models/parent.dart';

/// Interface for Parent Service operations
/// 
/// This interface defines the contract for parent-related operations.
abstract class IParentService {
  /// Get all parents as a stream
  Stream<List<Parent>> getParents();

  /// Get parent by ID
  Future<Parent?> getParentById(String id);

  /// Get parent stream by ID
  Stream<Parent?> getParentStream(String id);

  /// Create a new parent
  Future<void> addParent(Parent parent);

  /// Update an existing parent
  Future<void> updateParent(Parent parent);

  /// Delete a parent
  Future<void> deleteParent(String id);

  /// Update parent balance
  Future<void> updateBalance(String parentId, double newBalance);

  /// Add to parent balance
  Future<void> addBalance(String parentId, double amount);

  /// Deduct from parent balance
  Future<void> deductBalance(String parentId, double amount);

  /// Link student to parent
  Future<void> linkStudent(String parentId, String studentId);

  /// Unlink student from parent
  Future<void> unlinkStudent(String parentId, String studentId);

  /// Search parents by name or email
  Stream<List<Parent>> searchParents(String query);

  /// Import parents from CSV
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes);

  /// Export parents to CSV
  Future<List<int>> exportToCSV();

  /// Import parents from Excel
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes);

  /// Export parents to Excel
  Future<List<int>> exportToExcel();
}
