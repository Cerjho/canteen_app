import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:canteen_app/core/providers/date_refresh_provider.dart';
import 'package:canteen_app/shared/utils/date_refresh_controller.dart';

/// Week Picker Widget - allows selecting any week (past or future)
class WeekPicker extends ConsumerStatefulWidget {
  final DateTime selectedWeek;
  final ValueChanged<DateTime> onWeekChanged;
  final String? label;

  const WeekPicker({
    super.key,
    required this.selectedWeek,
    required this.onWeekChanged,
    this.label,
  });

  @override
  ConsumerState<WeekPicker> createState() => _WeekPickerState();
}

class _WeekPickerState extends ConsumerState<WeekPicker> {
  late final DateRefreshController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = DateRefreshController(onDayChanged: () {
      if (mounted) setState(() {});
    });
    _dateController.start();
    // Listen to the global date provider to rebuild when day rolls over.
    // Using ref.listen isn't possible here (no Riverpod Consumer), so we
    // rely on the controller already. Kept for parity with other widgets.
  }

  @override
  void dispose() {
    _dateController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekDateRange = _getWeekDateRange(widget.selectedWeek);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Previous week button
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final previousWeek = widget.selectedWeek.subtract(const Duration(days: 7));
                widget.onWeekChanged(previousWeek);
              },
              tooltip: 'Previous Week',
            ),
            
            // Week date range display with calendar picker
            InkWell(
              onTap: () => _showWeekPickerDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      weekDateRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Next week button
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final nextWeek = widget.selectedWeek.add(const Duration(days: 7));
                widget.onWeekChanged(nextWeek);
              },
              tooltip: 'Next Week',
            ),
            
            // Today button
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                final now = ref.read(dateRefreshProvider);
                final mondayOfWeek = _getMondayOfWeek(now);
                widget.onWeekChanged(mondayOfWeek);
              },
              icon: const Icon(Icons.today, size: 18),
              label: const Text('This Week'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show calendar dialog to pick any date (will snap to Monday of that week)
  Future<void> _showWeekPickerDialog(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedWeek,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select Any Date in Week',
    );

    if (pickedDate != null) {
      final mondayOfWeek = _getMondayOfWeek(pickedDate);
      widget.onWeekChanged(mondayOfWeek);
    }
  }

  /// Get Monday of the week for a given date
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Get week date range as string (e.g., "Jan 6 - Jan 10, 2025")
  String _getWeekDateRange(DateTime monday) {
    final friday = monday.add(const Duration(days: 4));
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (monday.month == friday.month) {
      return '${months[monday.month]} ${monday.day} - ${friday.day}, ${monday.year}';
    } else {
      return '${months[monday.month]} ${monday.day} - ${months[friday.month]} ${friday.day}, ${monday.year}';
    }
  }
}

/// Compact Week Picker - smaller version for inline use
class CompactWeekPicker extends StatefulWidget {
  final DateTime selectedWeek;
  final ValueChanged<DateTime> onWeekChanged;

  const CompactWeekPicker({
    super.key,
    required this.selectedWeek,
    required this.onWeekChanged,
  });

  @override
  State<CompactWeekPicker> createState() => _CompactWeekPickerState();
}

class _CompactWeekPickerState extends State<CompactWeekPicker> {
  late final DateRefreshController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = DateRefreshController(onDayChanged: () {
      if (mounted) setState(() {});
    });
    _dateController.start();
    // See note above — controller handles rebuilds for this widget.
  }

  @override
  void dispose() {
    _dateController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekDateRange = _getWeekDateRange(widget.selectedWeek);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final previousWeek = widget.selectedWeek.subtract(const Duration(days: 7));
            widget.onWeekChanged(previousWeek);
          },
          tooltip: 'Previous Week',
          visualDensity: VisualDensity.compact,
        ),
        
        InkWell(
          onTap: () => _showWeekPickerDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  weekDateRange,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final nextWeek = widget.selectedWeek.add(const Duration(days: 7));
            widget.onWeekChanged(nextWeek);
          },
          tooltip: 'Next Week',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Future<void> _showWeekPickerDialog(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedWeek,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select Any Date in Week',
    );

    if (pickedDate != null) {
      final mondayOfWeek = _getMondayOfWeek(pickedDate);
      widget.onWeekChanged(mondayOfWeek);
    }
  }

  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _getWeekDateRange(DateTime monday) {
    final friday = monday.add(const Duration(days: 4));
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (monday.month == friday.month) {
      return '${months[monday.month]} ${monday.day}-${friday.day}, ${monday.year}';
    } else {
      return '${months[monday.month]} ${monday.day} - ${months[friday.month]} ${friday.day}, ${monday.year}';
    }
  }
}
