import 'dart:async';

/// Simple controller that periodically checks for a day change and invokes a
/// callback when the date (year/month/day) changes.
class DateRefreshController {
  Timer? _timer;
  DateTime _currentDate = DateTime.now();
  final void Function() onDayChanged;

  DateRefreshController({required this.onDayChanged});

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _currentDate = DateTime.now();
    _timer = Timer.periodic(interval, (_) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!(_currentDate.year == today.year && _currentDate.month == today.month && _currentDate.day == today.day)) {
        _currentDate = today;
        try {
          onDayChanged();
        } catch (_) {}
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
