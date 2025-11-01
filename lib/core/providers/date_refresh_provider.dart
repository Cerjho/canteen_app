import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple StateNotifier that keeps the current 'today' (year/month/day)
/// and updates itself when the day rolls over. Consumers can watch
/// this provider to rebuild when the date changes.
class DateRefreshNotifier extends StateNotifier<DateTime> {
  Timer? _timer;

  DateRefreshNotifier() : super(DateTime.now()) {
    _start();
  }

  void _start() {
    _timer?.cancel();
    state = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Check every 30 seconds for a day change.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (today.difference(state).inDays != 0) {
        state = today;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dateRefreshProvider = StateNotifierProvider<DateRefreshNotifier, DateTime>((ref) {
  final notifier = DateRefreshNotifier();
  ref.onDispose(() {
    notifier.dispose();
  });
  return notifier;
});
