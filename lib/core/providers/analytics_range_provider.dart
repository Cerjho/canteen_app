import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:canteen_app/core/providers/date_refresh_provider.dart';

/// Analytics time range options
enum AnalyticsRange {
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year');

  final String label;
  const AnalyticsRange(this.label);
}

/// State for analytics range selection
class AnalyticsRangeState {
  final AnalyticsRange range;
  final DateTime selectedDate;

  AnalyticsRangeState({
    required this.range,
    required this.selectedDate,
  });

  AnalyticsRangeState copyWith({
    AnalyticsRange? range,
    DateTime? selectedDate,
  }) {
    return AnalyticsRangeState(
      range: range ?? this.range,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  /// Get start date based on range
  DateTime getStartDate() {
    switch (range) {
      case AnalyticsRange.thisWeek:
        return _getMondayOfWeek(selectedDate);
      case AnalyticsRange.thisMonth:
        return DateTime(selectedDate.year, selectedDate.month, 1);
      case AnalyticsRange.thisYear:
        return DateTime(selectedDate.year, 1, 1);
    }
  }

  /// Get end date based on range
  DateTime getEndDate() {
    switch (range) {
      case AnalyticsRange.thisWeek:
        final monday = _getMondayOfWeek(selectedDate);
        return monday.add(const Duration(days: 6));
      case AnalyticsRange.thisMonth:
        return DateTime(selectedDate.year, selectedDate.month + 1, 0);
      case AnalyticsRange.thisYear:
        return DateTime(selectedDate.year, 12, 31);
    }
  }

  /// Get Monday of the week for a given date
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Format date range as string
  String formatRange() {
    switch (range) {
      case AnalyticsRange.thisWeek:
        final monday = getStartDate();
        final sunday = getEndDate();
        return '${_formatDate(monday)} - ${_formatDate(sunday)}';
      case AnalyticsRange.thisMonth:
        return '${_getMonthName(selectedDate.month)} ${selectedDate.year}';
      case AnalyticsRange.thisYear:
        return '${selectedDate.year}';
    }
  }

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

/// Notifier for analytics range state
class AnalyticsRangeNotifier extends StateNotifier<AnalyticsRangeState> {
  final Ref ref;

  AnalyticsRangeNotifier(this.ref)
      : super(AnalyticsRangeState(
          range: AnalyticsRange.thisWeek,
          selectedDate: DateTime.now(),
        )) {
    // Initialize selectedDate from the centralized date provider so the
    // notifier doesn't capture a stale DateTime at construction time.
    state = state.copyWith(selectedDate: ref.read(dateRefreshProvider));
    // Listen to the centralized date refresh provider and update
    // the selected date when appropriate (i.e., if the selected
    // date represented the previous 'current' period).
  ref.listen<DateTime>(dateRefreshProvider, (previous, next) {
      if (previous == null) return;

      bool selectedWasCurrentPeriod = false;
      switch (state.range) {
        case AnalyticsRange.thisWeek:
          selectedWasCurrentPeriod = state.selectedDate.year == previous.year && state.selectedDate.month == previous.month && state.selectedDate.day == previous.day;
          break;
        case AnalyticsRange.thisMonth:
          selectedWasCurrentPeriod = state.selectedDate.year == previous.year && state.selectedDate.month == previous.month;
          break;
        case AnalyticsRange.thisYear:
          selectedWasCurrentPeriod = state.selectedDate.year == previous.year;
          break;
      }

      if (selectedWasCurrentPeriod) {
        // Move selectedDate forward to the new 'today' provided by next.
        state = state.copyWith(selectedDate: next);
      }
    });
  }

  /// Change the analytics range
  void setRange(AnalyticsRange range) {
    state = state.copyWith(range: range);
  }

  /// Change the selected date
  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  /// Move to previous period
  void moveToPrevious() {
    DateTime newDate;
    switch (state.range) {
      case AnalyticsRange.thisWeek:
        newDate = state.selectedDate.subtract(const Duration(days: 7));
        break;
      case AnalyticsRange.thisMonth:
        newDate = DateTime(
          state.selectedDate.year,
          state.selectedDate.month - 1,
          state.selectedDate.day,
        );
        break;
      case AnalyticsRange.thisYear:
        newDate = DateTime(
          state.selectedDate.year - 1,
          state.selectedDate.month,
          state.selectedDate.day,
        );
        break;
    }
    state = state.copyWith(selectedDate: newDate);
  }

  /// Move to next period
  void moveToNext() {
    DateTime newDate;
    switch (state.range) {
      case AnalyticsRange.thisWeek:
        newDate = state.selectedDate.add(const Duration(days: 7));
        break;
      case AnalyticsRange.thisMonth:
        newDate = DateTime(
          state.selectedDate.year,
          state.selectedDate.month + 1,
          state.selectedDate.day,
        );
        break;
      case AnalyticsRange.thisYear:
        newDate = DateTime(
          state.selectedDate.year + 1,
          state.selectedDate.month,
          state.selectedDate.day,
        );
        break;
    }
    state = state.copyWith(selectedDate: newDate);
  }

  /// Reset to current period
  void resetToCurrent() {
    state = state.copyWith(selectedDate: ref.read(dateRefreshProvider));
  }

  /// Check if current selection is in the future
  bool isFuture() {
    final now = ref.read(dateRefreshProvider);
    final endDate = state.getEndDate();
    return endDate.isAfter(now);
  }
}

/// Provider for analytics range state
final analyticsRangeProvider =
    StateNotifierProvider<AnalyticsRangeNotifier, AnalyticsRangeState>((ref) {
  return AnalyticsRangeNotifier(ref);
});
