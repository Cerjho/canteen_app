import 'package:intl/intl.dart';

/// Formatting utilities for the app
class FormatUtils {
  /// Format currency
  static String currency(double amount) {
    return NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(amount);
  }

  /// Format date
  static String date(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date with time
  static String dateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  /// Format time only
  static String time(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Format date for filename
  static String fileDate(DateTime date) {
    return DateFormat('yyyyMMdd_HHmmss').format(date);
  }

  /// Format date range
  static String dateRange(DateTime start, DateTime end) {
    return '${date(start)} - ${date(end)}';
  }

  /// Format relative date (Today, Yesterday, etc.)
  static String relativeDate(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return FormatUtils.date(date);
    }
  }
}
