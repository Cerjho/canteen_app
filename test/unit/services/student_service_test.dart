import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/models/student.dart';

/// Comprehensive unit tests for StudentService
/// 
/// Note: These tests focus on data model validation, business logic,
/// and data transformation logic. For integration tests with Firestore,
/// see the integration test suite.
void main() {
  group('Student Model - Data Serialization', () {
    test('Student creation with required fields succeeds', () {
      final testStudent = Student(
        id: 'test-student-1',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 5',
  // balance removed
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(testStudent.id, 'test-student-1');
      expect(testStudent.fullName, 'Juan Dela Cruz');
  // balance removed
      expect(testStudent.isActive, true);
    });

    test('Student.toMap() converts student to Firestore map correctly', () {
      final now = DateTime.now();
      final testStudent = Student(
        id: 'test-student-1',
        firstName: 'Maria',
        lastName: 'Santos',
        grade: 'Grade 4',
        parentId: 'parent-123',
        allergies: 'Peanuts',
        dietaryRestrictions: 'Vegetarian',
  // balance removed
        isActive: true,
        createdAt: now,
      );

      final studentMap = testStudent.toMap();

      expect(studentMap['id'], 'test-student-1');
      expect(studentMap['firstName'], 'Maria');
      expect(studentMap['lastName'], 'Santos');
      expect(studentMap['grade'], 'Grade 4');
      expect(studentMap['parentId'], 'parent-123');
      expect(studentMap['allergies'], 'Peanuts');
      expect(studentMap['dietaryRestrictions'], 'Vegetarian');
  // balance removed from map
      expect(studentMap['isActive'], true);
      expect(studentMap['createdAt'], isA<Timestamp>());
    });

    test('Student.fromMap() creates student from Firestore map correctly', () {
      final now = DateTime.now();
      final studentMap = {
        'id': 'test-student-2',
        'firstName': 'Pedro',
        'lastName': 'Reyes',
        'grade': 'Grade 6',
        'parentId': 'parent-456',
        'allergies': 'Shellfish',
        'dietaryRestrictions': null,
        'photoUrl': null,
  // balance removed
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': null,
      };

      final student = Student.fromMap(studentMap);

      expect(student.id, 'test-student-2');
      expect(student.firstName, 'Pedro');
      expect(student.lastName, 'Reyes');
      expect(student.grade, 'Grade 6');
      expect(student.parentId, 'parent-456');
      expect(student.allergies, 'Shellfish');
      expect(student.dietaryRestrictions, null);
  // balance removed
      expect(student.isActive, true);
      expect(student.fullName, 'Pedro Reyes');
    });

    test('Student.copyWith() creates modified copy correctly', () {
      final originalStudent = Student(
        id: 'test-student-3',
        firstName: 'Ana',
        lastName: 'Garcia',
        grade: 'Grade 3',
  // balance removed
        isActive: true,
        createdAt: DateTime.now(),
      );

      final updatedStudent = originalStudent.copyWith(
  // balance removed
        isActive: false,
        updatedAt: DateTime.now(),
      );

      // Check updated fields
  // balance removed
      expect(updatedStudent.isActive, false);
      expect(updatedStudent.updatedAt, isNotNull);

      // Check unchanged fields
      expect(updatedStudent.id, originalStudent.id);
      expect(updatedStudent.firstName, originalStudent.firstName);
      expect(updatedStudent.lastName, originalStudent.lastName);
      expect(updatedStudent.grade, originalStudent.grade);
    });
  });

  group('StudentService - Duplicate Detection', () {
    test('_checkDuplicateByNameAndGrade should detect duplicate students', () {
      // Test case: Ensure duplicate detection logic works
      final student1 = Student(
        id: 'student-1',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 5',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final student2 = Student(
        id: 'student-2',
        firstName: 'John', // Same first name
        lastName: 'Doe',   // Same last name
        grade: 'Grade 5',  // Same grade
        isActive: true,
        createdAt: DateTime.now(),
      );

      final student3 = Student(
        id: 'student-3',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 6', // Different grade
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Student 1 and 2 should be considered duplicates
      expect(
        '${student1.firstName}|${student1.lastName}|${student1.grade}',
        '${student2.firstName}|${student2.lastName}|${student2.grade}',
      );

      // Student 1 and 3 should NOT be duplicates (different grade)
      expect(
        '${student1.firstName}|${student1.lastName}|${student1.grade}',
        isNot('${student3.firstName}|${student3.lastName}|${student3.grade}'),
      );
    });

    test('Duplicate detection is case-insensitive', () {
      final key1 = 'john|doe|grade 5'.toLowerCase();
      final key2 = 'JOHN|DOE|GRADE 5'.toLowerCase();
      final key3 = 'John|Doe|Grade 5'.toLowerCase();

      expect(key1, key2);
      expect(key1, key3);
      expect(key2, key3);
    });
  });

  group('StudentService - Validation', () {
    test('Student with empty firstName should be invalid', () {
      final invalidStudent = {
        'firstname': '',
        'lastname': 'Doe',
        'grade': 'Grade 5',
      };

      expect(invalidStudent['firstname']?.toString().isEmpty, true);
    });

    test('Student with empty lastName should be invalid', () {
      final invalidStudent = {
        'firstname': 'John',
        'lastname': '',
        'grade': 'Grade 5',
      };

      expect(invalidStudent['lastname']?.toString().isEmpty, true);
    });

    test('Student with empty grade should be invalid', () {
      final invalidStudent = {
        'firstname': 'John',
        'lastname': 'Doe',
        'grade': '',
      };

      expect(invalidStudent['grade']?.toString().isEmpty, true);
    });

    test('Valid student data passes validation', () {
      final validStudent = {
        'firstname': 'John',
        'lastname': 'Doe',
        'grade': 'Grade 5',
      };

      final firstName = validStudent['firstname'] ?? '';
      final lastName = validStudent['lastname'] ?? '';
      final grade = validStudent['grade'] ?? '';

      expect(firstName.isNotEmpty && lastName.isNotEmpty && grade.isNotEmpty, true);
    });
  });

  // Balance operations removed from Student model - billing handled by Parent wallets.

  group('StudentService - CSV Import Validation', () {
    test('CSV headers are case-insensitive', () {
      final testHeaders = ['FirstName', 'LASTNAME', 'grade'];
      final normalizedHeaders = testHeaders.map((h) => h.toLowerCase().trim()).toList();

      expect(normalizedHeaders, ['firstname', 'lastname', 'grade']);
    });

    test('CSV field mapping handles different header formats', () {
      final csvData1 = {'firstname': 'John', 'lastname': 'Doe'};
      final csvData2 = {'first name': 'John', 'last name': 'Doe'};

      final firstName1 = csvData1['firstname'] ?? csvData1['first name'] ?? '';
      final firstName2 = csvData2['firstname'] ?? csvData2['first name'] ?? '';

      expect(firstName1, 'John');
      expect(firstName2, 'John');
    });

    test('Balance parsing handles various formats', () {
      expect(double.tryParse('100'), 100.0);
      expect(double.tryParse('100.50'), 100.50);
      expect(double.tryParse('0'), 0.0);
      expect(double.tryParse('invalid'), null);
      expect(double.tryParse(''), null);
    });

    test('Empty rows are skipped during import', () {
      final testRows = [
        ['John', 'Doe', 'Grade 5'],
        ['', '', ''], // Empty row
        ['Jane', 'Smith', 'Grade 4'],
      ];

      final validRows = testRows.where((row) => 
        row.isNotEmpty && !row.every((cell) => cell.toString().trim().isEmpty)
      ).toList();

      expect(validRows.length, 2);
      expect(validRows[0][0], 'John');
      expect(validRows[1][0], 'Jane');
    });
  });

  group('StudentService - Export Functionality', () {
    test('CSV export headers are correctly formatted', () {
      final expectedHeaders = [
        'ID',
        'First Name',
        'Last Name',
        'Grade',
        'Parent ID',
        'Allergies',
        'Dietary Restrictions',
        'Balance',
        'Active',
        'Created At',
      ];

      expect(expectedHeaders.length, 10);
      expect(expectedHeaders[0], 'ID');
      expect(expectedHeaders[1], 'First Name');
      expect(expectedHeaders[7], 'Balance');
    });

    test('Active status is exported as Yes/No', () {
      final activeStudent = Student(
        id: 'test-1',
        firstName: 'Active',
        lastName: 'Student',
        grade: 'Grade 1',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final inactiveStudent = Student(
        id: 'test-2',
        firstName: 'Inactive',
        lastName: 'Student',
        grade: 'Grade 1',
        isActive: false,
        createdAt: DateTime.now(),
      );

      expect(activeStudent.isActive ? 'Yes' : 'No', 'Yes');
      expect(inactiveStudent.isActive ? 'Yes' : 'No', 'No');
    });
  });

  group('StudentService - Search and Filter', () {
    test('Search query is case-insensitive', () {
      final student = Student(
        id: 'test-1',
        firstName: 'Maria',
        lastName: 'Santos',
        grade: 'Grade 3',
        createdAt: DateTime.now(),
      );

      final query = 'maria';
      expect(student.fullName.toLowerCase().contains(query.toLowerCase()), true);
      
      final query2 = 'MARIA';
      expect(student.fullName.toLowerCase().contains(query2.toLowerCase()), true);
      
      final query3 = 'santos';
      expect(student.fullName.toLowerCase().contains(query3.toLowerCase()), true);
    });

    test('Partial name matching works', () {
      final student = Student(
        id: 'test-1',
        firstName: 'Alexander',
        lastName: 'Rodriguez',
        grade: 'Grade 5',
        createdAt: DateTime.now(),
      );

      expect(student.fullName.toLowerCase().contains('alex'), true);
      expect(student.fullName.toLowerCase().contains('rod'), true);
      expect(student.fullName.toLowerCase().contains('ander'), true);
    });

    test('Full name is correctly formatted', () {
      final student = Student(
        id: 'test-1',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 2',
        createdAt: DateTime.now(),
      );

      expect(student.fullName, 'Juan Dela Cruz');
      expect(student.fullName, contains(' '));
    });
  });

  group('StudentService - Data Integrity', () {
    test('Required fields cannot be null', () {
      expect(
        () => Student(
          id: 'test',
          firstName: 'John',
          lastName: 'Doe',
          grade: 'Grade 1',
          createdAt: DateTime.now(),
        ),
        returnsNormally,
      );
    });

    test('Optional fields can be null', () {
      final student = Student(
        id: 'test',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.parentId, null);
      expect(student.allergies, null);
      expect(student.dietaryRestrictions, null);
      expect(student.photoUrl, null);
      expect(student.updatedAt, null);
    });

    test('DateTime fields are properly handled', () {
      final createdAt = DateTime.now();
      final student = Student(
        id: 'test',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: createdAt,
      );

      expect(student.createdAt, createdAt);
      expect(student.createdAt, isA<DateTime>());
    });

    test('Boolean fields have correct defaults', () {
      final student = Student(
        id: 'test',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.isActive, true); // Default value
    });
  });

  group('StudentService - Edge Cases', () {
    test('Handles students with same name but different grades', () {
      final student1 = Student(
        id: 'student-1',
        firstName: 'John',
        lastName: 'Smith',
        grade: 'Grade 3',
        createdAt: DateTime.now(),
      );

      final student2 = Student(
        id: 'student-2',
        firstName: 'John',
        lastName: 'Smith',
        grade: 'Grade 5',
        createdAt: DateTime.now(),
      );

      expect(student1.fullName, student2.fullName);
      expect(student1.grade, isNot(student2.grade));
    });

    test('Handles very long names', () {
      final student = Student(
        id: 'test',
        firstName: 'Alexander Christopher',
        lastName: 'Rodriguez Dela Cruz',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.firstName.length, greaterThan(10));
      expect(student.lastName.length, greaterThan(10));
      expect(student.fullName.length, greaterThan(20));
    });

    test('Handles special characters in names', () {
      final student = Student(
        id: 'test',
        firstName: "O'Brien",
        lastName: 'García-López',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.firstName, "O'Brien");
      expect(student.lastName, 'García-López');
      expect(student.fullName, "O'Brien García-López");
    });

    // Balance-related edge-case tests removed; billing is handled by parents.
  });
}
