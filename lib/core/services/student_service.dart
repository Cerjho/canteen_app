import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';
import '../constants/firestore_constants.dart';
import '../interfaces/i_student_service.dart';

/// Student Service - handles all Student-related Firestore operations
/// 
/// This service implements [IStudentService] and provides Firestore-backed
/// student management operations. Dependencies are injected via constructor
/// for better testability.
class StudentService implements IStudentService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  /// Creates a StudentService with optional dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance (defaults to FirebaseFirestore.instance)
  /// [uuid] - Optional Uuid instance (defaults to const Uuid())
  StudentService({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  /// Get all students
  @override
  Stream<List<Student>> getStudents() {
    return _firestore
        .collection(FirestoreConstants.studentsCollection)
        .orderBy(FirestoreConstants.lastName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList());
  }

  /// Get students by parent ID
  @override
  Stream<List<Student>> getStudentsByParent(String parentId) {
    return _firestore
        .collection(FirestoreConstants.studentsCollection)
        .where(FirestoreConstants.parentId, isEqualTo: parentId)
        .orderBy(FirestoreConstants.lastName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList());
  }

  /// Get student by ID
  @override
  Future<Student?> getStudentById(String id) async {
    final doc = await _firestore.collection(FirestoreConstants.studentsCollection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Student.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get student stream by ID
  @override
  Stream<Student?> getStudentStream(String id) {
    return _firestore
        .collection(FirestoreConstants.studentsCollection)
        .doc(id)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists && snapshot.data() != null ? Student.fromMap(snapshot.data()!) : null);
  }

  /// Create a new student
  @override
  Future<void> addStudent(Student student) async {
    // Check for duplicate by firstName + lastName + grade (case-insensitive)
    final existingStudent = await _checkDuplicateByNameAndGrade(
      student.firstName,
      student.lastName,
      student.grade,
    );
    if (existingStudent != null) {
      throw Exception(
        'A student with the name "${student.firstName} ${student.lastName}" in ${student.grade} already exists.'
      );
    }
    
    await _firestore.collection(FirestoreConstants.studentsCollection).doc(student.id).set(student.toMap());
  }

  /// Check if a student with the same firstName, lastName, and grade exists
  Future<Student?> _checkDuplicateByNameAndGrade(
    String firstName,
    String lastName,
    String grade,
  ) async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.studentsCollection)
        .where(FirestoreConstants.firstName, isEqualTo: firstName)
        .where(FirestoreConstants.lastName, isEqualTo: lastName)
        .where(FirestoreConstants.grade, isEqualTo: grade)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return Student.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  /// Update student
  @override
  Future<void> updateStudent(Student student) async {
    final updatedStudent = student.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection(FirestoreConstants.studentsCollection)
        .doc(student.id)
        .update(updatedStudent.toMap());
  }

  /// Delete a student
  @override
  Future<void> deleteStudent(String id) async {
    await _firestore.collection(FirestoreConstants.studentsCollection).doc(id).delete();
  }

  /// Update student balance
  // Student balance operations removed - billing handled on parent wallets

  /// Add to student balance
  // Removed addBalance - use parent wallet operations instead

  /// Deduct from student balance
  // Removed deductBalance - billing flows should update parent wallets only

  /// Assign student to parent
  Future<void> assignToParent(String studentId, String parentId) async {
    await _firestore.collection(FirestoreConstants.studentsCollection).doc(studentId).update({
      FirestoreConstants.parentId: parentId,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Search students by name
  @override
  Stream<List<Student>> searchStudents(String query) {
    return _firestore
        .collection(FirestoreConstants.studentsCollection)
        .orderBy(FirestoreConstants.firstName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromMap(doc.data()))
            .where((student) =>
                student.fullName.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  /// Filter students by grade
  @override
  Stream<List<Student>> getStudentsByGrade(String grade) {
    return _firestore
        .collection(FirestoreConstants.studentsCollection)
        .where(FirestoreConstants.grade, isEqualTo: grade)
        .orderBy(FirestoreConstants.lastName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList());
  }

  /// Check if student ID exists
  Future<bool> studentExists(String id) async {
    final doc = await _firestore.collection(FirestoreConstants.studentsCollection).doc(id).get();
    return doc.exists;
  }

  /// Import students from CSV
  /// Implements the interface requirement for CSV import
  @override
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes) async {
    return await importStudentsFromFile(
      fileBytes: Uint8List.fromList(bytes),
      fileName: 'import.csv',
    );
  }

  /// Export students to CSV
  /// Implements the interface requirement for CSV export
  @override
  Future<List<int>> exportToCSV() async {
    final students = await getStudents().first;
    final csvString = await exportStudentsToCsv(students);
    return utf8.encode(csvString);
  }

  /// Import students from Excel
  /// Implements the interface requirement for Excel import
  @override
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes) async {
    return await importStudentsFromFile(
      fileBytes: Uint8List.fromList(bytes),
      fileName: 'import.xlsx',
    );
  }

  /// Export students to Excel
  /// Implements the interface requirement for Excel export
  @override
  Future<List<int>> exportToExcel() async {
    final students = await getStudents().first;
    final excelBytes = await exportStudentsToExcel(students);
    return excelBytes;
  }

  /// Import students from CSV/Excel file
  /// Returns a map with 'success', 'failed', and 'duplicates' counts
  Future<Map<String, dynamic>> importStudentsFromFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    List<Map<String, dynamic>> parsedData = [];
    
    try {
      // Auto-detect file type and parse
      if (fileName.toLowerCase().endsWith('.csv')) {
        parsedData = await _parseCsvFile(fileBytes);
      } else if (fileName.toLowerCase().endsWith('.xlsx') || 
                 fileName.toLowerCase().endsWith('.xls')) {
        parsedData = await _parseExcelFile(fileBytes);
      } else {
        throw Exception('Unsupported file format. Please use CSV or Excel (.xlsx)');
      }

      // Validate and import students
      return await _batchImportStudents(parsedData);
    } catch (e) {
      throw Exception('Error importing file: $e');
    }
  }

  /// Parse CSV file
  Future<List<Map<String, dynamic>>> _parseCsvFile(Uint8List bytes) async {
    final csvString = utf8.decode(bytes);
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    
    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // First row should be headers
    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final dataRows = rows.skip(1);

    List<Map<String, dynamic>> result = [];
    for (var row in dataRows) {
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      Map<String, dynamic> studentData = {};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        studentData[headers[i]] = row[i]?.toString().trim() ?? '';
      }
      result.add(studentData);
    }

    return result;
  }

  /// Parse Excel file
  Future<List<Map<String, dynamic>>> _parseExcelFile(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    
    if (excel.tables.isEmpty) {
      throw Exception('Excel file has no sheets');
    }

    // Get first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    
    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('Excel sheet is empty');
    }

    // First row should be headers
    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
        .toList();
    
    final dataRows = sheet.rows.skip(1);

    List<Map<String, dynamic>> result = [];
    for (var row in dataRows) {
      if (row.isEmpty || row.every((cell) => cell?.value == null)) {
        continue; // Skip empty rows
      }

      Map<String, dynamic> studentData = {};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        final cellValue = row[i]?.value?.toString().trim() ?? '';
        studentData[headers[i]] = cellValue;
      }
      result.add(studentData);
    }

    return result;
  }

  /// Batch import students with validation
  Future<Map<String, dynamic>> _batchImportStudents(
    List<Map<String, dynamic>> data,
  ) async {
    int successCount = 0;
    int duplicateCount = 0;
    final List<Map<String, dynamic>> failedItems = [];

    // Fetch existing students to check duplicates
    final existingSnapshot = await _firestore.collection(FirestoreConstants.studentsCollection).get();
    final Set<String> existingStudents = existingSnapshot.docs.map((doc) {
      final data = doc.data();
      final firstName = (data[FirestoreConstants.firstName] as String? ?? '').toLowerCase().trim();
      final lastName = (data[FirestoreConstants.lastName] as String? ?? '').toLowerCase().trim();
      final grade = (data[FirestoreConstants.grade] as String? ?? '').toLowerCase().trim();
      return '$firstName|$lastName|$grade'; // Composite key
    }).toSet();

    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    for (int i = 0; i < data.length; i++) {
      try {
        final studentData = data[i];
        
        // Validate required fields
        final firstName = studentData['firstname'] ?? studentData['first name'] ?? '';
        final lastName = studentData['lastname'] ?? studentData['last name'] ?? '';
        final grade = studentData['grade'] ?? '';

        if (firstName.isEmpty || lastName.isEmpty || grade.isEmpty) {
          failedItems.add({
            'row': i + 2, // +2 because: +1 for 1-based index, +1 for header row
            'error': 'Missing required fields (firstName, lastName, or grade)',
          });
          continue;
        }

        // Check for duplicates by name and grade
        final studentKey = '${firstName.toLowerCase().trim()}|${lastName.toLowerCase().trim()}|${grade.toLowerCase().trim()}';
        if (existingStudents.contains(studentKey)) {
          duplicateCount++;
          continue;
        }

        // Generate unique ID
        final studentId = _uuid.v4();

        final student = Student(
          id: studentId,
          firstName: firstName,
          lastName: lastName,
          grade: grade,
          parentId: studentData['parentid'] ?? studentData['parent id'],
          allergies: studentData['allergies'],
          dietaryRestrictions: studentData['dietaryrestrictions'] ?? 
                              studentData['dietary restrictions'],
          isActive: true,
          createdAt: DateTime.now(),
        );

        final docRef = _firestore.collection(FirestoreConstants.studentsCollection).doc(studentId);
        batch.set(docRef, student.toMap());
        operationCount++;
        successCount++;
        existingStudents.add(studentKey); // Prevent duplicates within same import

        // Firestore batch has a limit of 500 operations
        if (operationCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      } catch (e) {
        failedItems.add({
          'row': i + 2,
          'error': e.toString(),
        });
      }
    }

    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }

    return {
      'success': successCount,
      'duplicates': duplicateCount,
      'failed': failedItems,
    };
  }

  /// Export students to CSV
  Future<String> exportStudentsToCsv(List<Student> students) async {
    List<List<dynamic>> rows = [];
    
    // Headers (student balance removed)
    rows.add([
      'ID',
      'First Name',
      'Last Name',
      'Grade',
      'Parent ID',
      'Allergies',
      'Dietary Restrictions',
      'Active',
      'Created At',
    ]);

    // Data rows
    for (var student in students) {
      rows.add([
        student.id,
        student.firstName,
        student.lastName,
        student.grade,
        student.parentId ?? '',
        student.allergies ?? '',
        student.dietaryRestrictions ?? '',
        student.isActive ? 'Yes' : 'No',
        student.createdAt.toIso8601String(),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Export students to Excel
  Future<Uint8List> exportStudentsToExcel(List<Student> students) async {
    final excel = Excel.createExcel();
    final sheet = excel['Students'];

    // Headers (student balance removed)
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('First Name'),
      TextCellValue('Last Name'),
      TextCellValue('Grade'),
      TextCellValue('Parent ID'),
      TextCellValue('Allergies'),
      TextCellValue('Dietary Restrictions'),
      TextCellValue('Active'),
      TextCellValue('Created At'),
    ]);

    // Data rows
    for (var student in students) {
      sheet.appendRow([
        TextCellValue(student.id),
        TextCellValue(student.firstName),
        TextCellValue(student.lastName),
        TextCellValue(student.grade),
        TextCellValue(student.parentId ?? ''),
        TextCellValue(student.allergies ?? ''),
        TextCellValue(student.dietaryRestrictions ?? ''),
        TextCellValue(student.isActive ? 'Yes' : 'No'),
        TextCellValue(student.createdAt.toIso8601String()),
      ]);
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    return Uint8List.fromList(bytes);
  }

  /// Get students count
  Future<int> getStudentsCount() async {
    final snapshot = await _firestore.collection(FirestoreConstants.studentsCollection).count().get();
    return snapshot.count ?? 0;
  }

  /// Get active students count
  Future<int> getActiveStudentsCount() async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.studentsCollection)
        .where(FirestoreConstants.isActive, isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}
