import '../models/student.dart';

/// Interface for Student Service operations
/// 
/// This interface defines the contract for student-related operations.
/// Implementations of this interface can provide different backends
/// (e.g., Firestore, mock data, REST API, etc.)
abstract class IStudentService {
  /// Get all students as a stream
  /// 
  /// Returns a stream of all students ordered by last name.
  Stream<List<Student>> getStudents();

  /// Get students by parent ID
  /// 
  /// Returns a stream of students linked to a specific parent.
  /// 
  /// [parentId] - The ID of the parent
  Stream<List<Student>> getStudentsByParent(String parentId);

  /// Get student by ID
  /// 
  /// Returns a single student by their ID, or null if not found.
  /// 
  /// [id] - The student ID
  Future<Student?> getStudentById(String id);

  /// Get student stream by ID
  /// 
  /// Returns a stream for a single student by their ID.
  /// 
  /// [id] - The student ID
  Stream<Student?> getStudentStream(String id);

  /// Create a new student
  /// 
  /// Adds a new student to the database.
  /// Throws an exception if a duplicate is found.
  /// 
  /// [student] - The student to create
  Future<void> addStudent(Student student);

  /// Update an existing student
  /// 
  /// Updates an existing student's information.
  /// 
  /// [student] - The student with updated information
  Future<void> updateStudent(Student student);

  /// Delete a student
  /// 
  /// Removes a student from the database.
  /// 
  /// [id] - The ID of the student to delete
  Future<void> deleteStudent(String id);

  /// Update student balance
  /// 
  /// Updates a student's account balance.
  /// 
  /// [studentId] - The ID of the student
  /// [newBalance] - The new balance amount
  // Student balance operations removed - billing is handled by parent wallets

  /// Search students by name
  /// 
  /// Searches for students by first or last name.
  /// 
  /// [query] - The search query
  Stream<List<Student>> searchStudents(String query);

  /// Get students by grade
  /// 
  /// Returns all students in a specific grade.
  /// 
  /// [grade] - The grade level
  Stream<List<Student>> getStudentsByGrade(String grade);

  /// Import students from CSV
  /// 
  /// Imports multiple students from a CSV byte array.
  /// 
  /// [bytes] - The CSV file bytes
  /// Returns a map with 'success', 'failed', and 'errors' keys
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes);

  /// Export students to CSV
  /// 
  /// Exports all students to a CSV byte array.
  /// 
  /// Returns the CSV file as bytes
  Future<List<int>> exportToCSV();

  /// Import students from Excel
  /// 
  /// Imports multiple students from an Excel byte array.
  /// 
  /// [bytes] - The Excel file bytes
  /// Returns a map with 'success', 'failed', and 'errors' keys
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes);

  /// Export students to Excel
  /// 
  /// Exports all students to an Excel byte array.
  /// 
  /// Returns the Excel file as bytes
  Future<List<int>> exportToExcel();
}
