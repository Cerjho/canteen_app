/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.code,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() {
    if (code != null) {
      return '$runtimeType [$code]: $message';
    }
    return '$runtimeType: $message';
  }
}

/// Exception thrown when authentication fails
class AuthenticationException extends AppException {
  AuthenticationException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when authorization fails (insufficient permissions)
class AuthorizationException extends AppException {
  AuthorizationException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when validation fails
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(
    super.message, {
    this.fieldErrors,
    super.code,
    super.originalException,
    super.stackTrace,
  });

  @override
  String toString() {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final errors = fieldErrors!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return '$runtimeType: $message ($errors)';
    }
    return super.toString();
  }
}

/// Exception thrown when a resource is not found
class NotFoundException extends AppException {
  final String resourceType;
  final String? resourceId;

  NotFoundException(
    this.resourceType, {
    this.resourceId,
    super.code,
    super.originalException,
    super.stackTrace,
  }) : super(_buildMessage(resourceType, resourceId));

  static String _buildMessage(String resourceType, String? resourceId) {
    if (resourceId != null) {
      return '$resourceType with ID "$resourceId" not found';
    }
    return '$resourceType not found';
  }
}

/// Exception thrown when a duplicate resource is detected
class DuplicateException extends AppException {
  final String resourceType;
  final String? identifier;

  DuplicateException(
    this.resourceType, {
    this.identifier,
    super.code,
    super.originalException,
    super.stackTrace,
  }) : super(_buildMessage(resourceType, identifier));

  static String _buildMessage(String resourceType, String? identifier) {
    if (identifier != null) {
      return 'A $resourceType with identifier "$identifier" already exists';
    }
    return 'A $resourceType with these details already exists';
  }
}

/// Exception thrown when a network operation fails
class NetworkException extends AppException {
  NetworkException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when a Firestore operation fails
class FirestoreException extends AppException {
  FirestoreException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when a storage operation fails
class StorageException extends AppException {
  StorageException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when a business rule is violated
class BusinessRuleException extends AppException {
  BusinessRuleException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown for student-related errors
class StudentException extends AppException {
  StudentException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown for menu-related errors
class MenuException extends AppException {
  MenuException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown for order-related errors
class OrderException extends AppException {
  OrderException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown for parent-related errors
class ParentException extends AppException {
  ParentException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when a top-up related errors
class TopupException extends AppException {
  TopupException(
    super.message, {
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

// ============================================================================
// Specific Exception Types
// ============================================================================

// Authentication Specific
class UserNotFoundException extends AuthenticationException {
  UserNotFoundException([String? userId])
      : super(
          userId != null ? 'User not found: $userId' : 'User not found',
          code: 'USER_NOT_FOUND',
        );
}

class InvalidCredentialsException extends AuthenticationException {
  InvalidCredentialsException()
      : super(
          'Invalid email or password',
          code: 'INVALID_CREDENTIALS',
        );
}

class EmailAlreadyInUseException extends AuthenticationException {
  EmailAlreadyInUseException()
      : super(
          'Email address is already in use',
          code: 'EMAIL_IN_USE',
        );
}

class WeakPasswordException extends AuthenticationException {
  WeakPasswordException()
      : super(
          'Password is too weak',
          code: 'WEAK_PASSWORD',
        );
}

class NotSignedInException extends AuthenticationException {
  NotSignedInException()
      : super(
          'No user is currently signed in',
          code: 'NOT_SIGNED_IN',
        );
}

// Authorization Specific
class InsufficientPermissionsException extends AuthorizationException {
  InsufficientPermissionsException([String? requiredRole])
      : super(
          requiredRole != null
              ? 'Insufficient permissions. Required role: $requiredRole'
              : 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
        );
}

// Validation Specific
class RequiredFieldException extends ValidationException {
  RequiredFieldException(String fieldName)
      : super(
          'Required field is missing: $fieldName',
          code: 'REQUIRED_FIELD_MISSING',
        );
}

class InvalidFormatException extends ValidationException {
  InvalidFormatException(String fieldName, String expectedFormat)
      : super(
          'Invalid format for $fieldName. Expected: $expectedFormat',
          code: 'INVALID_FORMAT',
        );
}

// Business Logic Specific
class InsufficientBalanceException extends BusinessRuleException {
  final double required;
  final double available;

  InsufficientBalanceException(this.required, this.available)
      : super(
          'Insufficient balance. Required: \$$required, Available: \$$available',
          code: 'INSUFFICIENT_BALANCE',
        );
}

class InsufficientStockException extends BusinessRuleException {
  final String itemName;
  final int requested;
  final int available;

  InsufficientStockException(this.itemName, this.requested, this.available)
      : super(
          'Insufficient stock for $itemName. Requested: $requested, Available: $available',
          code: 'INSUFFICIENT_STOCK',
        );
}

class MenuItemUnavailableException extends MenuException {
  MenuItemUnavailableException(String itemName)
      : super(
          'Menu item is not available: $itemName',
          code: 'MENU_ITEM_UNAVAILABLE',
        );
}

class InvalidOrderStateException extends OrderException {
  InvalidOrderStateException(String currentState, String attemptedAction)
      : super(
          'Cannot $attemptedAction order in $currentState state',
          code: 'INVALID_ORDER_STATE',
        );
}

// File Operation Specific
class InvalidFileFormatException extends StorageException {
  InvalidFileFormatException(String fileName, List<String> expectedFormats)
      : super(
          'Invalid file format: $fileName. Expected: ${expectedFormats.join(", ")}',
          code: 'INVALID_FILE_FORMAT',
        );
}

class EmptyFileException extends StorageException {
  EmptyFileException()
      : super(
          'File is empty or contains no data',
          code: 'EMPTY_FILE',
        );
}

class MissingColumnsException extends StorageException {
  MissingColumnsException(List<String> missingColumns)
      : super(
          'Required columns missing: ${missingColumns.join(", ")}',
          code: 'MISSING_COLUMNS',
        );
}

// Network Specific
class NoInternetException extends NetworkException {
  NoInternetException()
      : super(
          'No internet connection',
          code: 'NO_INTERNET',
        );
}

class TimeoutException extends NetworkException {
  TimeoutException()
      : super(
          'Request timed out',
          code: 'TIMEOUT',
        );
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Convert Firebase Auth exception to custom exception
AppException convertFirebaseAuthException(dynamic error) {
  final errorCode = error.toString().toLowerCase();

  if (errorCode.contains('user-not-found')) {
    return UserNotFoundException();
  } else if (errorCode.contains('wrong-password') ||
      errorCode.contains('invalid-credential')) {
    return InvalidCredentialsException();
  } else if (errorCode.contains('email-already-in-use')) {
    return EmailAlreadyInUseException();
  } else if (errorCode.contains('weak-password')) {
    return WeakPasswordException();
  } else if (errorCode.contains('network-request-failed')) {
    return NoInternetException();
  }

  return AuthenticationException(
    'Authentication error: ${error.toString()}',
    code: 'AUTH_ERROR',
    originalException: error,
  );
}

/// Convert Firebase Firestore exception to custom exception
AppException convertFirestoreException(dynamic error, {String? resourceType}) {
  final errorCode = error.toString().toLowerCase();

  if (errorCode.contains('not-found')) {
    return NotFoundException(resourceType ?? 'Resource');
  } else if (errorCode.contains('permission-denied')) {
    return InsufficientPermissionsException();
  } else if (errorCode.contains('already-exists')) {
    return DuplicateException(resourceType ?? 'Resource');
  } else if (errorCode.contains('network')) {
    return NoInternetException();
  }

  return FirestoreException(
    'Database error: ${error.toString()}',
    code: 'DATABASE_ERROR',
    originalException: error,
  );
}
