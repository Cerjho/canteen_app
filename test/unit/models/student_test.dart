import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/models/student.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Student Model Tests', () {
    test('should create student with all fields', () {
      final now = DateTime.now();
      final student = Student(
        id: 'test-id',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 1',
        parentId: 'parent-id',
        allergies: 'Peanuts',
        dietaryRestrictions: 'Vegetarian',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(student.id, 'test-id');
      expect(student.firstName, 'Juan');
      expect(student.lastName, 'Dela Cruz');
      expect(student.fullName, 'Juan Dela Cruz');
      expect(student.grade, 'Grade 1');
  // student.balance removed; ensure other fields set
      expect(student.isActive, true);
    });

    test('should create student with minimal fields', () {
      final now = DateTime.now();
      final student = Student(
        id: 'test-id',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 1',
        createdAt: now,
      );

      expect(student.parentId, isNull);
      expect(student.allergies, isNull);
  // balance removed
      expect(student.isActive, true);
    });

    test('should convert to map correctly', () {
      final now = DateTime.now();
      final student = Student(
        id: 'test-id',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 1',
        isActive: true,
        createdAt: now,
      );

      final map = student.toMap();

      expect(map['id'], 'test-id');
      expect(map['firstName'], 'Juan');
      expect(map['lastName'], 'Dela Cruz');
      expect(map['grade'], 'Grade 1');
  // balance removed from map
      expect(map['isActive'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('should create from map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-id',
        'firstName': 'Juan',
        'lastName': 'Dela Cruz',
        'grade': 'Grade 1',
        'balance': 100.50,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final student = Student.fromMap(map);

      expect(student.id, 'test-id');
      expect(student.firstName, 'Juan');
      expect(student.lastName, 'Dela Cruz');
      expect(student.fullName, 'Juan Dela Cruz');
  // balance removed
      expect(student.isActive, true);
    });

    test('should handle copyWith correctly', () {
      final now = DateTime.now();
      final student = Student(
        id: 'test-id',
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        grade: 'Grade 1',
  // balance removed
        createdAt: now,
      );

      final updated = student.copyWith(
        firstName: 'Maria',
      );

  expect(updated.id, 'test-id');
  expect(updated.firstName, 'Maria');
  expect(updated.lastName, 'Dela Cruz');
    });
  });
}
