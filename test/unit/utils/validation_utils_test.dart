import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/utils/validation_utils.dart';

void main() {
  group('ValidationUtils Tests', () {
    group('Sanitization', () {
      test('should sanitize string input', () {
        expect(ValidationUtils.sanitizeString('  Hello  World  '), 'Hello World');
        expect(ValidationUtils.sanitizeString('Test<>{}'), 'Test');
        expect(ValidationUtils.sanitizeString('Normal Text'), 'Normal Text');
      });

      test('should sanitize email input', () {
        expect(ValidationUtils.sanitizeEmail('  Test@Email.COM  '), 'test@email.com');
        expect(ValidationUtils.sanitizeEmail('USER@EXAMPLE.COM'), 'user@example.com');
      });

      test('should sanitize phone number', () {
        expect(ValidationUtils.sanitizePhone('0915-123-4567'), '09151234567');
        expect(ValidationUtils.sanitizePhone('+639151234567'), '+639151234567');
        expect(ValidationUtils.sanitizePhone('(0915) 123-4567'), '09151234567');
      });

      test('should sanitize price input', () {
        expect(ValidationUtils.sanitizePrice(100.50), 100.50);
        expect(ValidationUtils.sanitizePrice(100), 100.0);
        expect(ValidationUtils.sanitizePrice('₱123.45'), 123.45);
        expect(ValidationUtils.sanitizePrice('invalid'), 0.0);
      });
    });

    group('Email Validation', () {
      test('should validate correct emails', () {
        expect(ValidationUtils.email('test@example.com'), isNull);
        expect(ValidationUtils.email('user.name@example.co.uk'), isNull);
        expect(ValidationUtils.email('test+alias@example.com'), isNull);
      });

      test('should reject invalid emails', () {
        expect(ValidationUtils.email(''), 'Email is required');
        expect(ValidationUtils.email(null), 'Email is required');
        expect(ValidationUtils.email('invalid'), isNot(isNull));
        expect(ValidationUtils.email('@example.com'), isNot(isNull));
        expect(ValidationUtils.email('test@'), isNot(isNull));
      });
    });

    group('Password Validation', () {
      test('should validate correct passwords', () {
        expect(ValidationUtils.password('password123'), isNull);
        expect(ValidationUtils.password('123456'), isNull);
      });

      test('should reject invalid passwords', () {
        expect(ValidationUtils.password(''), 'Password is required');
        expect(ValidationUtils.password(null), 'Password is required');
        expect(ValidationUtils.password('12345'), isNot(isNull));
      });
    });

    group('Phone Validation', () {
      test('should validate correct Philippine phone numbers', () {
        expect(ValidationUtils.phone('09151234567'), isNull);
        expect(ValidationUtils.phone('+639151234567'), isNull);
        expect(ValidationUtils.phone(''), isNull); // Optional
      });

      test('should reject invalid phone numbers', () {
        expect(ValidationUtils.phone('1234567'), isNot(isNull));
        expect(ValidationUtils.phone('091512345'), isNot(isNull));
        expect(ValidationUtils.phone('12345678901'), isNot(isNull));
      });
    });

    group('Required Field Validation', () {
      test('should validate required fields', () {
        expect(ValidationUtils.required('value', 'Field'), isNull);
      });

      test('should reject empty required fields', () {
        expect(ValidationUtils.required('', 'Field'), 'Field is required');
        expect(ValidationUtils.required(null, 'Field'), 'Field is required');
        expect(ValidationUtils.required('   ', 'Field'), 'Field is required');
      });
    });

    group('Positive Number Validation', () {
      test('should validate positive numbers', () {
        expect(ValidationUtils.positiveNumber('1', 'Field'), isNull);
        expect(ValidationUtils.positiveNumber('100.50', 'Field'), isNull);
      });

      test('should reject non-positive numbers', () {
        expect(ValidationUtils.positiveNumber('0', 'Field'), isNot(isNull));
        expect(ValidationUtils.positiveNumber('-1', 'Field'), isNot(isNull));
        expect(ValidationUtils.positiveNumber('invalid', 'Field'), isNot(isNull));
      });
    });

    group('Integer Validation', () {
      test('should validate integers', () {
        expect(ValidationUtils.integer('1', 'Field'), isNull);
        expect(ValidationUtils.integer('100', 'Field'), isNull);
      });

      test('should reject non-integers', () {
        expect(ValidationUtils.integer('1.5', 'Field'), isNot(isNull));
        expect(ValidationUtils.integer('invalid', 'Field'), isNot(isNull));
        expect(ValidationUtils.integer('', 'Field'), 'Field is required');
      });
    });
  });

  group('ValidationResult Tests', () {
    test('should create success result', () {
      final result = ValidationResult.success();
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('should create failure result with errors', () {
      final result = ValidationResult.failure(
        errors: {'field1': 'Error 1', 'field2': 'Error 2'},
        generalError: 'General error',
      );
      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.generalError, 'General error');
      expect(result.firstError, 'General error');
    });

    test('should throw exception on invalid result', () {
      final result = ValidationResult.failure(generalError: 'Test error');
      expect(() => result.throwIfInvalid(), throwsA(isA<Exception>()));
    });

    test('should not throw exception on valid result', () {
      final result = ValidationResult.success();
      expect(() => result.throwIfInvalid(), returnsNormally);
    });
  });
}
