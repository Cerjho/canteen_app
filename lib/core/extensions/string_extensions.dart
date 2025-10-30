/// String extension methods for common operations
///
/// Provides convenient methods for string manipulation,
/// validation, and formatting used throughout the canteen app.
library;

extension StringExtensions on String {
  /// Capitalize the first letter of the string
  /// 
  /// Example:
  /// ```dart
  /// 'hello'.capitalize; // 'Hello'
  /// 'WORLD'.capitalize; // 'World'
  /// ```
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  /// Capitalize the first letter of each word (title case)
  /// 
  /// Example:
  /// ```dart
  /// 'hello world'.titleCase; // 'Hello World'
  /// 'john doe'.titleCase; // 'John Doe'
  /// ```
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Check if the string is a valid email address
  /// 
  /// Example:
  /// ```dart
  /// 'john@example.com'.isValidEmail; // true
  /// 'invalid-email'.isValidEmail; // false
  /// ```
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Check if the string is a valid phone number (Philippine format)
  /// 
  /// Accepts formats: 09123456789, +639123456789, 9123456789
  /// 
  /// Example:
  /// ```dart
  /// '09123456789'.isValidPhoneNumber; // true
  /// '+639123456789'.isValidPhoneNumber; // true
  /// '123'.isValidPhoneNumber; // false
  /// ```
  bool get isValidPhoneNumber {
    final phoneRegex = RegExp(r'^(\+?63|0)?9\d{9}$');
    return phoneRegex.hasMatch(replaceAll(RegExp(r'\s|-'), ''));
  }

  /// Check if the string contains only letters and spaces
  /// 
  /// Example:
  /// ```dart
  /// 'John Doe'.isAlpha; // true
  /// 'John123'.isAlpha; // false
  /// ```
  bool get isAlpha {
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(this);
  }

  /// Check if the string contains only digits
  /// 
  /// Example:
  /// ```dart
  /// '12345'.isNumeric; // true
  /// '123abc'.isNumeric; // false
  /// ```
  bool get isNumeric {
    return RegExp(r'^\d+$').hasMatch(this);
  }

  /// Truncate string to a specified length and add ellipsis if needed
  /// 
  /// Example:
  /// ```dart
  /// 'This is a long text'.truncate(10); // 'This is a...'
  /// 'Short'.truncate(10); // 'Short'
  /// ```
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Remove all whitespace from the string
  /// 
  /// Example:
  /// ```dart
  /// ' hello world '.removeWhitespace; // 'helloworld'
  /// ```
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Convert string to snake_case
  /// 
  /// Example:
  /// ```dart
  /// 'HelloWorld'.toSnakeCase; // 'hello_world'
  /// 'helloWorld'.toSnakeCase; // 'hello_world'
  /// ```
  String get toSnakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Convert string to camelCase
  /// 
  /// Example:
  /// ```dart
  /// 'hello_world'.toCamelCase; // 'helloWorld'
  /// 'hello world'.toCamelCase; // 'helloWorld'
  /// ```
  String get toCamelCase {
    final words = split(RegExp(r'[\s_-]+'));
    if (words.isEmpty) return this;
    
    return words.first.toLowerCase() +
        words.skip(1).map((word) => word.capitalize).join();
  }

  /// Reverse the string
  /// 
  /// Example:
  /// ```dart
  /// 'hello'.reverse; // 'olleh'
  /// ```
  String get reverse {
    return split('').reversed.join();
  }

  /// Check if string contains any of the given substrings
  /// 
  /// Example:
  /// ```dart
  /// 'hello world'.containsAny(['hello', 'goodbye']); // true
  /// 'hello world'.containsAny(['goodbye', 'farewell']); // false
  /// ```
  bool containsAny(List<String> substrings) {
    return substrings.any((substring) => contains(substring));
  }

  /// Check if string contains all of the given substrings
  /// 
  /// Example:
  /// ```dart
  /// 'hello world'.containsAll(['hello', 'world']); // true
  /// 'hello world'.containsAll(['hello', 'goodbye']); // false
  /// ```
  bool containsAll(List<String> substrings) {
    return substrings.every((substring) => contains(substring));
  }

  /// Remove HTML tags from string
  /// 
  /// Example:
  /// ```dart
  /// '<p>Hello</p>'.removeHtmlTags; // 'Hello'
  /// ```
  String get removeHtmlTags {
    return replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Format as Philippine Peso (₱)
  /// 
  /// Assumes the string is a valid number
  /// 
  /// Example:
  /// ```dart
  /// '150.50'.toPhpFormat(); // '₱150.50'
  /// '1000'.toPhpFormat(); // '₱1,000.00'
  /// ```
  String toPhpFormat() {
    final amount = double.tryParse(this) ?? 0.0;
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    
    // Add thousand separators
    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
    
    return '₱$withCommas.$decimalPart';
  }
}
