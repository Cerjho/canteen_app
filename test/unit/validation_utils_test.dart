import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/utils/validation_utils.dart';

void main() {
  group('ValidationUtils - Email', () {
    test('should return null for valid email', () {
      expect(ValidationUtils.email('test@example.com'), null);
      expect(ValidationUtils.email('user.name@domain.co.uk'), null);
    });

    test('should return error for invalid email', () {
      expect(ValidationUtils.email('invalid'), isNotNull);
      expect(ValidationUtils.email('test@'), isNotNull);
      expect(ValidationUtils.email('@example.com'), isNotNull);
    });

    test('should return error for empty email', () {
      expect(ValidationUtils.email(''), isNotNull);
      expect(ValidationUtils.email(null), isNotNull);
    });
  });

  group('ValidationUtils - Password', () {
    test('should return null for valid password', () {
      expect(ValidationUtils.password('123456'), null);
      expect(ValidationUtils.password('mypassword'), null);
    });

    test('should return error for short password', () {
      expect(ValidationUtils.password('12345'), isNotNull);
      expect(ValidationUtils.password('abc'), isNotNull);
    });

    test('should return error for empty password', () {
      expect(ValidationUtils.password(''), isNotNull);
      expect(ValidationUtils.password(null), isNotNull);
    });
  });

  group('ValidationUtils - Phone', () {
    test('should return null for valid Philippine mobile numbers', () {
      expect(ValidationUtils.phone('09171234567'), null);
      expect(ValidationUtils.phone('+639171234567'), null);
    });

    test('should return error for invalid phone numbers', () {
      expect(ValidationUtils.phone('12345'), isNotNull);
      expect(ValidationUtils.phone('08123456789'), isNotNull);
    });

    test('should return null for empty phone (optional field)', () {
      expect(ValidationUtils.phone(''), null);
      expect(ValidationUtils.phone(null), null);
    });
  });

  group('ValidationUtils - Sanitization', () {
    test('should sanitize strings correctly', () {
      expect(ValidationUtils.sanitizeString('  hello  '), 'hello');
      expect(ValidationUtils.sanitizeString('test<script>'), 'testscript');
      expect(ValidationUtils.sanitizeString('multi  spaces'), 'multi spaces');
    });

    test('should sanitize email correctly', () {
      expect(ValidationUtils.sanitizeEmail('  TEST@EXAMPLE.COM  '), 'test@example.com');
    });

    test('should sanitize phone correctly', () {
      expect(ValidationUtils.sanitizePhone('(091) 712-34567'), '09171234567');
      expect(ValidationUtils.sanitizePhone('+63 917 123 4567'), '+639171234567');
    });

    test('should sanitize price correctly', () {
      expect(ValidationUtils.sanitizePrice('₱123.45'), 123.45);
      expect(ValidationUtils.sanitizePrice(100), 100.0);
      expect(ValidationUtils.sanitizePrice(99.99), 99.99);
    });
  });

  group('ValidationResult', () {
    test('should create success result', () {
      final result = ValidationResult.success();
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('should create failure result', () {
      final result = ValidationResult.failure(
        generalError: 'Test error',
        errors: {'field': 'Field error'},
      );
      expect(result.isValid, false);
      expect(result.generalError, 'Test error');
      expect(result.errors['field'], 'Field error');
    });

    test('should get first error', () {
      final result = ValidationResult.failure(
        errors: {'field1': 'Error 1', 'field2': 'Error 2'},
      );
      expect(result.firstError, isNotNull);
    });
  });
}
