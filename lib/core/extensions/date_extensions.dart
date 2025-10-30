/// Date and DateTime extension methods for common operations
///
/// Provides convenient methods for date formatting, manipulation,
/// and comparisons used throughout the canteen app.
library;

extension DateTimeExtensions on DateTime {
  /// Format as YYYY-MM-DD (ISO 8601 date format)
  /// 
  /// Example:
  /// ```dart
  /// DateTime.now().toYYYYMMDD(); // "2025-10-14"
  /// ```
  String toYYYYMMDD() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  /// Get the Monday of the week containing this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).monday; // Returns Monday of that week
  /// ```
  DateTime get monday {
    return subtract(Duration(days: weekday - 1));
  }

  /// Get the Sunday of the week containing this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).sunday; // Returns Sunday of that week
  /// ```
  DateTime get sunday {
    return add(Duration(days: DateTime.daysPerWeek - weekday));
  }

  /// Get the Friday of the week containing this date
  /// 
  /// Useful for weekly menu which runs Monday-Friday
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).friday; // Returns Friday of that week
  /// ```
  DateTime get friday {
    final daysUntilFriday = DateTime.friday - weekday;
    return add(Duration(days: daysUntilFriday));
  }

  /// Check if this date is today
  /// 
  /// Example:
  /// ```dart
  /// DateTime.now().isToday; // true
  /// DateTime(2025, 10, 13).isToday; // false (if today is Oct 14)
  /// ```
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if this date is in the past (excluding today)
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 13).isPast; // true (if today is Oct 14)
  /// DateTime.now().isPast; // false
  /// ```
  bool get isPast {
    return isBefore(DateTime.now()) && !isToday;
  }

  /// Check if this date is in the future (excluding today)
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 15).isFuture; // true (if today is Oct 14)
  /// DateTime.now().isFuture; // false
  /// ```
  bool get isFuture {
    return isAfter(DateTime.now()) && !isToday;
  }

  /// Check if this date is a weekend (Saturday or Sunday)
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 18).isWeekend; // true (Saturday)
  /// DateTime(2025, 10, 14).isWeekend; // false (Tuesday)
  /// ```
  bool get isWeekend {
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  /// Check if this date is a weekday (Monday to Friday)
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).isWeekday; // true (Tuesday)
  /// DateTime(2025, 10, 18).isWeekday; // false (Saturday)
  /// ```
  bool get isWeekday {
    return !isWeekend;
  }

  /// Get the date at midnight (00:00:00)
  /// 
  /// Useful for date comparisons without time component
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14, 15, 30).dateOnly; // 2025-10-14 00:00:00.000
  /// ```
  DateTime get dateOnly {
    return DateTime(year, month, day);
  }

  /// Check if this date is the same day as another date
  /// 
  /// Ignores time component
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14, 9, 0).isSameDay(DateTime(2025, 10, 14, 17, 0)); // true
  /// ```
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Get the number of days until this date from today
  /// 
  /// Returns negative if date is in the past
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 16).daysUntil; // 2 (if today is Oct 14)
  /// DateTime(2025, 10, 12).daysUntil; // -2 (if today is Oct 14)
  /// ```
  int get daysUntil {
    final today = DateTime.now().dateOnly;
    final target = dateOnly;
    return target.difference(today).inDays;
  }

  /// Get the number of days since this date from today
  /// 
  /// Returns negative if date is in the future
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 12).daysSince; // 2 (if today is Oct 14)
  /// DateTime(2025, 10, 16).daysSince; // -2 (if today is Oct 14)
  /// ```
  int get daysSince {
    final today = DateTime.now().dateOnly;
    final target = dateOnly;
    return today.difference(target).inDays;
  }

  /// Add a number of days to this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).addDays(7); // 2025-10-21
  /// ```
  DateTime addDays(int days) {
    return add(Duration(days: days));
  }

  /// Subtract a number of days from this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).subtractDays(7); // 2025-10-07
  /// ```
  DateTime subtractDays(int days) {
    return subtract(Duration(days: days));
  }

  /// Get the start of the month for this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).startOfMonth; // 2025-10-01 00:00:00.000
  /// ```
  DateTime get startOfMonth {
    return DateTime(year, month, 1);
  }

  /// Get the end of the month for this date
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).endOfMonth; // 2025-10-31 23:59:59.999
  /// ```
  DateTime get endOfMonth {
    return DateTime(year, month + 1, 0, 23, 59, 59, 999);
  }

  /// Format date as "Day, Month Date, Year" (e.g., "Tuesday, October 14, 2025")
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).toFullDateString(); // "Tuesday, October 14, 2025"
  /// ```
  String toFullDateString() {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${weekdays[weekday - 1]}, ${months[month - 1]} $day, $year';
  }

  /// Format date as "Mon, Oct 14" (short format)
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).toShortDateString(); // "Mon, Oct 14"
  /// ```
  String toShortDateString() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${weekdays[weekday - 1]}, ${months[month - 1]} $day';
  }

  /// Get week number of the year (1-53)
  /// 
  /// Following ISO 8601 week date system
  /// 
  /// Example:
  /// ```dart
  /// DateTime(2025, 10, 14).weekNumber; // Returns week number
  /// ```
  int get weekNumber {
    final firstDayOfYear = DateTime(year, 1, 1);
    final dayOfYear = difference(firstDayOfYear).inDays;
    return ((dayOfYear + firstDayOfYear.weekday) / 7).ceil();
  }
}
