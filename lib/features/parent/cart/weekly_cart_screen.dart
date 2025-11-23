// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/weekly_cart_provider.dart';
import 'package:canteen_app/core/utils/format_utils.dart';
import 'package:canteen_app/core/providers/app_providers.dart';
import 'package:flutter/services.dart';

/// WeeklyCartScreen - Full-week order management screen
/// 
/// Features:
/// - View all 5 weekdays (Mon-Fri) in expandable sections
/// - Copy day operations (e.g., copy Monday to other days)
/// - Clear individual days or entire week
/// - Weekly summary with total cost and nutrition
/// - Submit all 5 days at once
class WeeklyCartScreen extends ConsumerStatefulWidget {
  /// Starting date for the week (typically the first day with orders)
  final DateTime weekStartDate;

  const WeeklyCartScreen({
    super.key,
    required this.weekStartDate,
  });

  @override
  ConsumerState<WeeklyCartScreen> createState() => _WeeklyCartScreenState();
}

class _WeeklyCartScreenState extends ConsumerState<WeeklyCartScreen> {
  @override
  void initState() {
    super.initState();
    // Rebuild when the app-level day changes so UI that relies on "today" updates after midnight
    ref.listenManual<DateTime>(dateRefreshProvider, (_, __) {
      if (mounted) setState(() {});
    });
  }
  // (Removed edit quantity dialog; weekly edit is simplified to keep modal compact)
  void _showOrderConfirmationModal(WeeklySummary summary, Map<String, Map<String, dynamic>> grouped, double parentBalance) {
    final total = summary.totalCost;
    final remaining = parentBalance - total;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Weekly Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Days: ${summary.daysWithOrders}'),
              Text('Items: ${summary.totalItems}'),
              SizedBox(height: 8.h),
              Text('Total: ${FormatUtils.currency(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'Wallet after: ${FormatUtils.currency(remaining)}',
                style: TextStyle(color: remaining < 0 ? Colors.red : Colors.green),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _submitWeeklyOrder();
              },
              child: const Text('Confirm & Submit'),
            ),
          ],
        );
      },
    );
  }
  /// Group cart items by student, then by day, then by mealType, then by time
  Map<String, Map<String, dynamic>> _groupCartByStudentDayMeal(List<WeeklyCartItem> allItems) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in allItems) {
      final studentId = item.studentId ?? 'unknown';
      final studentName = item.studentName ?? 'Unknown';
      final day = item.date;
      final mealType = item.mealType ?? 'Other';
  final time = item.mealType == 'snack' ? (item.time ?? 'Other') : null;

      grouped.putIfAbsent(studentId, () => {
        'studentName': studentName,
        'days': <DateTime, Map<String, dynamic>>{},
      });
      final days = grouped[studentId]!['days'] as Map<DateTime, Map<String, dynamic>>;
      days.putIfAbsent(day, () => {'meals': <String, Map<String, dynamic>>{}});
      final meals = days[day]!['meals'] as Map<String, Map<String, dynamic>>;
      meals.putIfAbsent(mealType, () => {'times': <String, List<WeeklyCartItem>>{}, 'items': <WeeklyCartItem>[]});
  if (mealType == 'snack') {
        final times = meals[mealType]!['times'] as Map<String, List<WeeklyCartItem>>;
        times.putIfAbsent(time!, () => []);
        times[time]!.add(item);
      } else {
        (meals[mealType]!['items'] as List<WeeklyCartItem>).add(item);
      }
    }
    return grouped;
  }

  /// Submit weekly order
  Future<void> _submitWeeklyOrder() async {
    final cart = ref.read(weeklyCartProvider.notifier);
    final summary = ref.read(weeklyCartSummaryProvider);
    
    if (summary.daysWithOrders == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add items to at least one day first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Remove student selection modal and use all items in cart
    final currentUserId = ref.read(currentUserProvider).value?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify parent account. Please sign in.'), backgroundColor: Colors.red),
      );
      return;
    }

    final parent = ref.read(currentParentProvider).value;
    final parentBalance = parent?.balance ?? 0.0;
    final requiredTotal = summary.totalCost;
    if (parentBalance < requiredTotal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet: ${FormatUtils.currency(parentBalance)} < required ${FormatUtils.currency(requiredTotal)}. Please top up and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show dialog while processing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final createdOrderIds = <String>[];
      final allItems = ref.read(weeklyCartProvider).values.expand((x) => x).toList();
      final grouped = _groupCartByStudentDayMeal(allItems);

      final orderService = ref.read(orderServiceProvider);

      // Iterate per student and per day; create one order per day/student
      for (final entry in grouped.entries) {
        final studentId = entry.key;
        final days = entry.value['days'] as Map<DateTime, Map<String, dynamic>>;

        for (final dayEntry in days.entries) {
          final day = dayEntry.key;
          final meals = dayEntry.value['meals'] as Map<String, Map<String, dynamic>>;

          // Flatten items for this day
          final items = <Map<String, dynamic>>[];
          double dayTotal = 0.0;
          for (final mealEntry in meals.entries) {
            final mealType = mealEntry.key;
            final data = mealEntry.value;
            if (mealType == 'snack') {
              final times = data['times'] as Map<String, List<WeeklyCartItem>>;
              for (final t in times.values) {
                for (final it in t) {
                  items.add({
                    'menuItemId': it.menuItem.id,
                    'menuItemName': it.menuItem.name,
                    'price': it.menuItem.price,
                    'quantity': it.quantity,
                  });
                  dayTotal += it.menuItem.price * it.quantity;
                }
              }
            } else {
              final list = data['items'] as List<WeeklyCartItem>;
              for (final it in list) {
                items.add({
                  'menuItemId': it.menuItem.id,
                  'menuItemName': it.menuItem.name,
                  'price': it.menuItem.price,
                  'quantity': it.quantity,
                });
                dayTotal += it.menuItem.price * it.quantity;
              }
            }
          }

          if (items.isEmpty) continue;

          // Place the order atomically (this deducts balance per order)
          final newOrderId = await orderService.placeOrder(
            parentId: currentUserId,
            studentId: studentId,
            items: items,
            totalAmount: dayTotal,
            deliveryDate: DateTime(day.year, day.month, day.day),
          );
          createdOrderIds.add(newOrderId);
        }
      }

  // Refresh UI streams
      ref.invalidate(parentOrdersProvider);
      ref.invalidate(parentTransactionsStreamProvider(currentUserId));
  ref.invalidate(currentParentProvider);

      // Capture navigator before awaiting to avoid using BuildContext across async gaps
  final navigator = Navigator.of(context);
  if (!mounted) return;
      navigator.pop(); // Close loading dialog
      // Show custom success screen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: EdgeInsets.all(24.w),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48.sp),
                  SizedBox(height: 16.h),
                  Text('Orders successfully submitted!', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12.h),
                  Text('Created ${createdOrderIds.length} order(s).', style: TextStyle(fontSize: 15.sp)),
                  SizedBox(height: 12.h),
                  Text('Estimated ready by lunch', style: TextStyle(fontSize: 15.sp)),
                  SizedBox(height: 18.h),
                  ElevatedButton.icon(
                    icon: Icon(Icons.share),
                    label: Text('Share Receipt'),
                    onPressed: () {
                      final summaryText = 'Orders: ${createdOrderIds.join(', ')}\nTotal: ${FormatUtils.currency(summary.totalCost)}\nETA: Ready by lunch';
                      // TODO: Implement PDF or share intent
                      // For now, just copy to clipboard
                      Clipboard.setData(ClipboardData(text: summaryText));
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Receipt copied to clipboard!')),
                      );
                    },
                  ),
                  SizedBox(height: 18.h),
                  ElevatedButton(
                    child: Text('Go to Orders'),
                                onPressed: () {
                                  Navigator.pop(dialogContext); // Close dialog
                                  cart.clearWeek();
                                  // TODO: Implement redirect to Orders tab
                                  // For now, pop to root
                                  navigator.popUntil((route) => route.isFirst);
                                },
                  ),
                ],
              ),
            ),
          );
        },
      );
      // TODO: Trigger Firebase push notification with order details and ETA
    } catch (e) {
      if (!mounted) return;
      // navigator might not be defined if an error occured before capture; close dialog via root navigator as safe fallback
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Order Failed'),
          content: Text('Failed to place weekly orders: $e'),
          actions: [
            TextButton(
              child: const Text('Retry'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _submitWeeklyOrder();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
    }
  }

  // Student selection handled by shared dialog (widgets/student_selection_dialog.dart)


  /// Build weekly summary card
  Widget _buildWeeklySummaryCard(WeeklySummary summary) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.all(12.w),
      elevation: 3,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16.sp,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Weekly Summary',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // Total cost
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: theme.textTheme.bodyMedium?.color?.withAlpha((0.8 * 255).round()),
                  ),
                ),
                Text(
                  FormatUtils.currency(summary.totalCost),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatChip(
                  icon: Icons.restaurant_menu,
                  label: '${summary.totalItems} items',
                ),
                _buildStatChip(
                  icon: Icons.calendar_month,
                  label: '${summary.daysWithOrders} days',
                ),
              ],
            ),
            // Category breakdown
            if (summary.categoryBreakdown.isNotEmpty) ...[
              SizedBox(height: 10.h),
              const Divider(),
              SizedBox(height: 8.h),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color?.withAlpha((0.8 * 255).round()),
                ),
              ),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: summary.categoryBreakdown.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key} (${entry.value})', style: TextStyle(fontSize: 10.sp)),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build stat chip helper
  Widget _buildStatChip({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: theme.iconTheme.color?.withAlpha((0.7 * 255).round())),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color?.withAlpha((0.8 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(weeklyCartSummaryProvider);
    final allItems = ref.watch(weeklyCartProvider).values.expand((x) => x).toList();
    final grouped = _groupCartByStudentDayMeal(allItems);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weekly Order',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: theme.appBarTheme.titleTextStyle?.color),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          // Clear week button removed for now
        ],
      ),
      body: Column(
        children: [
          _buildWeeklySummaryCard(summary),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              children: [
                ...grouped.entries.map((studentEntry) {
                  final studentName = studentEntry.value['studentName'] as String;
                  final days = studentEntry.value['days'] as Map<DateTime, Map<String, dynamic>>;
                  final studentTotal = days.values.expand((d) => d['meals'].values.expand((m) {
                    if (m['items'] != null) {
                      return m['items'] as List<WeeklyCartItem>;
                    } else if (m['times'] != null) {
                      return (m['times'] as Map<String, List<WeeklyCartItem>>).values.expand((t) => t);
                    }
                    return <WeeklyCartItem>[];
                  })).fold(0.0, (sum, item) => sum + item.menuItem.price * item.quantity);
                  return ExpansionTile(
                    title: Text('👧 $studentName', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                    subtitle: Text('Total: ${FormatUtils.currency(studentTotal)}'),
                    children: [
                      ...days.entries.map((dayEntry) {
                        final day = dayEntry.key;
                        final meals = dayEntry.value['meals'] as Map<String, Map<String, dynamic>>;
                        return Padding(
                          padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
                          child: ExpansionTile(
                            title: Text('- ${DateFormat.EEEE().format(day)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.sp)),
                            children: [
                              ...meals.entries.map((mealEntry) {
                                final mealType = mealEntry.key;
                                final mealData = mealEntry.value;
                                if (mealType == 'snack') {
                                  final times = mealData['times'] as Map<String, List<WeeklyCartItem>>;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('   - Snack:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp)),
                                      ...times.entries.map((timeEntry) {
                                        final time = timeEntry.key;
                                        final items = timeEntry.value;
                                        return Padding(
                                          padding: EdgeInsets.only(left: 16.w),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('      - $time:', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13.sp)),
                                              ...items.map((item) => Padding(
                                                padding: EdgeInsets.only(left: 12.w, bottom: 4.h),
                                                child: Text('         - ${item.menuItem.name} ×${item.quantity}', style: TextStyle(fontSize: 13.sp)),
                                              )),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                } else {
                                  final items = mealData['items'] as List<WeeklyCartItem>;
                                  return Padding(
                                    padding: EdgeInsets.only(left: 12.w, bottom: 4.h),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('   - $mealType:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.sp)),
                                        ...items.map((item) => Padding(
                                          padding: EdgeInsets.only(left: 12.w, bottom: 2.h),
                                          child: Text('      - ${item.menuItem.name} ×${item.quantity}', style: TextStyle(fontSize: 13.sp)),
                                        )),
                                      ],
                                    ),
                                  );
                                }
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
          _buildBottomActionBar(summary),
        ],
      ),
    );
  }


  /// Build individual item row

  /// Build quantity controls

  /// Build bottom action bar
  Widget _buildBottomActionBar(WeeklySummary summary) {
    final allItems = ref.watch(weeklyCartProvider).values.expand((x) => x).toList();
    final grouped = _groupCartByStudentDayMeal(allItems);
    final parentBalance = ref.watch(
      currentParentProvider.select((a) => a.value?.balance ?? 0.0),
    );
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total display
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Total',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    FormatUtils.currency(summary.totalCost),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${summary.daysWithOrders} day(s) • ${summary.totalItems} items',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            // Submit button
            ElevatedButton(
              onPressed: summary.daysWithOrders > 0
                  ? () => _showOrderConfirmationModal(summary, grouped, parentBalance)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  SizedBox(width: 8.w),
                  Text(
                    'Submit Order',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
