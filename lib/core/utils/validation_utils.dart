import '../exceptions/app_exceptions.dart';
import '../constants/app_constants.dart';

/// Validation utilities for forms with input sanitization
class ValidationUtils {
  /// Sanitize string input by trimming and removing potentially dangerous characters
  static String sanitizeString(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>{}\\]'), '') // Remove potentially dangerous characters
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }
  
  /// Sanitize email input
  static String sanitizeEmail(String email) {
    return email.trim().toLowerCase();
  }
  
  /// Sanitize phone number (remove non-numeric characters except +)
  static String sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }
  
  /// Sanitize price input
  static double sanitizePrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
  
  /// Validate email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  /// Validate password
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate required field
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate phone number (Philippine format)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    final cleaned = sanitizePhone(value);
    final phoneRegex = RegExp(r'^(\+639|09)\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Enter a valid Philippine mobile number';
    }
    return null;
  }

  /// Validate positive number
  static String? positiveNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Enter a valid number';
    }
    if (number <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Validate integer
  static String? integer(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = int.tryParse(value);
    if (number == null) {
      return 'Enter a valid integer';
    }
    return null;
  }
  
  /// Validate price
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    
    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }
    
    if (price < AppConstants.minPrice) {
      return 'Price must be at least ${AppConstants.currencySymbol}${AppConstants.minPrice}';
    }
    
    if (price > AppConstants.maxPrice) {
      return 'Price cannot exceed ${AppConstants.currencySymbol}${AppConstants.maxPrice}';
    }
    
    return null;
  }
  
  /// Validate balance
  static String? validateBalance(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Balance is optional
    }
    
    final balance = double.tryParse(value);
    if (balance == null) {
      return 'Please enter a valid balance';
    }
    
    if (balance < AppConstants.minBalance) {
      return 'Balance cannot be negative';
    }
    
    if (balance > AppConstants.maxBalance) {
      return 'Balance cannot exceed ${AppConstants.currencySymbol}${AppConstants.maxBalance}';
    }
    
    return null;
  }
  
  /// Validate stock quantity
  static String? validateStockQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Stock is optional
    }
    
    final stock = int.tryParse(value);
    if (stock == null) {
      return 'Please enter a valid stock quantity';
    }
    
    if (stock < AppConstants.minStockQuantity) {
      return 'Stock quantity cannot be negative';
    }
    
    if (stock > AppConstants.maxStockQuantity) {
      return 'Stock quantity cannot exceed ${AppConstants.maxStockQuantity}';
    }
    
    return null;
  }
  
  /// Validate string length
  static String? validateLength(
    String? value,
    String fieldName, {
    int? min,
    int? max,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (min != null && value.length < min) {
      return '$fieldName must be at least $min characters long';
    }
    
    if (max != null && value.length > max) {
      return '$fieldName must not exceed $max characters';
    }
    
    return null;
  }
  
  /// Validate file size
  static String? validateFileSize(int sizeInBytes, int maxSizeInBytes) {
    if (sizeInBytes > maxSizeInBytes) {
      final maxSizeMB = (maxSizeInBytes / (1024 * 1024)).toStringAsFixed(1);
      return 'File size must not exceed $maxSizeMB MB';
    }
    return null;
  }
  
  /// Validate file extension
  static String? validateFileExtension(
    String filename,
    List<String> allowedExtensions,
  ) {
    final extension = filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return 'Only ${allowedExtensions.join(', ')} files are allowed';
    }
    return null;
  }
}

/// Result of validation operation
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;
  final String? generalError;
  
  ValidationResult({
    required this.isValid,
    this.errors = const {},
    this.generalError,
  });
  
  factory ValidationResult.success() {
    return ValidationResult(isValid: true);
  }
  
  factory ValidationResult.failure({
    Map<String, String>? errors,
    String? generalError,
  }) {
    return ValidationResult(
      isValid: false,
      errors: errors ?? {},
      generalError: generalError,
    );
  }
  
  /// Throw exception if validation failed
  void throwIfInvalid() {
    if (!isValid) {
      throw ValidationException(
        generalError ?? 'Validation failed',
        fieldErrors: errors.isNotEmpty ? errors : null,
      );
    }
  }
  
  /// Get first error message
  String? get firstError {
    if (generalError != null) return generalError;
    if (errors.isNotEmpty) return errors.values.first;
    return null;
  }
}
