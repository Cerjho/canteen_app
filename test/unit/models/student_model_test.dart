import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/models/student.dart';

void main() {
  group('Student Model Tests', () {
    test('should create student with required fields', () {
      final student = Student(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.id, 'test-id');
      expect(student.firstName, 'John');
      expect(student.lastName, 'Doe');
      expect(student.grade, 'Grade 1');
  // balance removed
      expect(student.isActive, true);
    });

    test('should generate full name correctly', () {
      final student = Student(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

      expect(student.fullName, 'John Doe');
    });

    test('should convert to map and back correctly', () {
      final now = DateTime.now();
      final student = Student(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: now,
      );

      final map = student.toMap();
      expect(map['id'], 'test-id');
      expect(map['firstName'], 'John');
  // balance removed
    });

    test('should create copy with modified fields', () {
      final student = Student(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
        grade: 'Grade 1',
        createdAt: DateTime.now(),
      );

  final updated = student.copyWith(isActive: false);

      expect(updated.isActive, false);
      expect(updated.firstName, 'John'); // Unchanged
    });
  });
}
