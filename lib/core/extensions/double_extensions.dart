/// Double and numeric extension methods for common operations
///
/// Provides convenient methods for number formatting,
/// rounding, and currency operations used throughout the canteen app.
library;

extension DoubleExtensions on double {
  /// Format as Philippine Peso (₱) with proper formatting
  /// 
  /// Example:
  /// ```dart
  /// 150.50.toPhp(); // '₱150.50'
  /// 1500.0.toPhp(); // '₱1,500.00'
  /// 1234567.89.toPhp(); // '₱1,234,567.89'
  /// ```
  String toPhp() {
    final parts = toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    
    // Add thousand separators
    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
    
    return '₱$withCommas.$decimalPart';
  }

  /// Format as Philippine Peso without decimals (for whole amounts)
  /// 
  /// Example:
  /// ```dart
  /// 150.50.toPhpWhole(); // '₱151'
  /// 1500.0.toPhpWhole(); // '₱1,500'
  /// ```
  String toPhpWhole() {
    final rounded = round();
    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
    
    return '₱$formatted';
  }

  /// Round to specified number of decimal places
  /// 
  /// Example:
  /// ```dart
  /// 3.14159.roundTo(2); // 3.14
  /// 150.456.roundTo(1); // 150.5
  /// ```
  double roundTo(int decimalPlaces) {
    final mod = 10.0 * decimalPlaces;
    return ((this * mod).round() / mod);
  }

  /// Round to 2 decimal places (common for currency)
  /// 
  /// Example:
  /// ```dart
  /// 150.456.roundTo2(); // 150.46
  /// 99.994.roundTo2(); // 99.99
  /// ```
  double roundTo2() {
    return roundTo(2);
  }

  /// Check if the number is within a percentage range of another number
  /// 
  /// Example:
  /// ```dart
  /// 105.0.isWithinPercentOf(100.0, 10); // true (within 10%)
  /// 120.0.isWithinPercentOf(100.0, 10); // false (more than 10%)
  /// ```
  bool isWithinPercentOf(double target, double percentage) {
    final difference = (this - target).abs();
    final allowedDifference = target * (percentage / 100);
    return difference <= allowedDifference;
  }

  /// Calculate percentage of another number
  /// 
  /// Example:
  /// ```dart
  /// 25.0.percentOf(100.0); // 25.0
  /// 50.0.percentOf(200.0); // 25.0
  /// ```
  double percentOf(double total) {
    if (total == 0) return 0;
    return (this / total) * 100;
  }

  /// Add percentage to the number
  /// 
  /// Example:
  /// ```dart
  /// 100.0.addPercent(10); // 110.0
  /// 200.0.addPercent(50); // 300.0
  /// ```
  double addPercent(double percentage) {
    return this * (1 + percentage / 100);
  }

  /// Subtract percentage from the number
  /// 
  /// Example:
  /// ```dart
  /// 100.0.subtractPercent(10); // 90.0
  /// 200.0.subtractPercent(50); // 100.0
  /// ```
  double subtractPercent(double percentage) {
    return this * (1 - percentage / 100);
  }

  /// Check if number is positive
  /// 
  /// Example:
  /// ```dart
  /// 5.0.isPositive; // true
  /// (-5.0).isPositive; // false
  /// 0.0.isPositive; // false
  /// ```
  bool get isPositive => this > 0;

  /// Check if number is negative
  /// 
  /// Example:
  /// ```dart
  /// (-5.0).isNegative; // true
  /// 5.0.isNegative; // false
  /// 0.0.isNegative; // false
  /// ```
  bool get isNegativeValue => this < 0;

  /// Check if number is zero
  /// 
  /// Example:
  /// ```dart
  /// 0.0.isZero; // true
  /// 0.001.isZero; // false
  /// ```
  bool get isZero => this == 0;

  /// Clamp value between min and max
  /// 
  /// Example:
  /// ```dart
  /// 150.0.clampBetween(100.0, 200.0); // 150.0
  /// 50.0.clampBetween(100.0, 200.0); // 100.0
  /// 250.0.clampBetween(100.0, 200.0); // 200.0
  /// ```
  double clampBetween(double min, double max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  /// Format with thousand separators
  /// 
  /// Example:
  /// ```dart
  /// 1234567.89.withThousandSeparator(); // '1,234,567.89'
  /// 1000.0.withThousandSeparator(); // '1,000.00'
  /// ```
  String withThousandSeparator({int decimalPlaces = 2}) {
    final parts = toStringAsFixed(decimalPlaces).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    
    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
    
    return '$withCommas.$decimalPart';
  }

  /// Convert to compact notation (K, M, B)
  /// 
  /// Example:
  /// ```dart
  /// 1500.0.toCompact(); // '1.5K'
  /// 1500000.0.toCompact(); // '1.5M'
  /// 1500000000.0.toCompact(); // '1.5B'
  /// ```
  String toCompact() {
    if (abs() >= 1000000000) {
      return '${(this / 1000000000).toStringAsFixed(1)}B';
    } else if (abs() >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (abs() >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    } else {
      return toStringAsFixed(0);
    }
  }
}

/// Extension on int to provide similar functionality
extension IntExtensions on int {
  /// Format as Philippine Peso (₱)
  /// 
  /// Example:
  /// ```dart
  /// 150.toPhp(); // '₱150.00'
  /// 1500.toPhp(); // '₱1,500.00'
  /// ```
  String toPhp() => toDouble().toPhp();

  /// Format as Philippine Peso without decimals
  /// 
  /// Example:
  /// ```dart
  /// 150.toPhpWhole(); // '₱150'
  /// 1500.toPhpWhole(); // '₱1,500'
  /// ```
  String toPhpWhole() => toDouble().toPhpWhole();

  /// Check if number is positive
  bool get isPositive => this > 0;

  /// Check if number is negative
  bool get isNegativeValue => this < 0;

  /// Check if number is zero
  bool get isZero => this == 0;

  /// Format with thousand separators
  /// 
  /// Example:
  /// ```dart
  /// 1234567.withThousandSeparator(); // '1,234,567'
  /// ```
  String withThousandSeparator() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
  }

  /// Convert to compact notation (K, M, B)
  /// 
  /// Example:
  /// ```dart
  /// 1500.toCompact(); // '1.5K'
  /// 1500000.toCompact(); // '1.5M'
  /// ```
  String toCompact() => toDouble().toCompact();
}
