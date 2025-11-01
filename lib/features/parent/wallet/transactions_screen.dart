import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/providers/user_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/date_refresh_provider.dart';
import '../../../core/providers/transaction_providers.dart';

/// Simple full-screen transactions list for the parent user
enum TransactionFilter { all, pending, topups, deductions }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionFilter _filter = TransactionFilter.all;

  @override
  void initState() {
    super.initState();
    // Listen to global date refresh and rebuild when day changes so
    // any `DateTime.now()` fallbacks refresh in the UI.
      ref.listenManual<DateTime?>(
        dateRefreshProvider,
        (previous, next) {
          // simply rebuild when the day changes
          setState(() {});
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final parentAsync = ref.watch(currentParentProvider);
    return parentAsync.when(
      data: (parent) {
        final parentId = parent?.userId;
        if (parentId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transactions')),
            body: const Center(child: Text('No parent profile found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transactions'),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: DropdownButton<TransactionFilter>(
                  value: _filter,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _filter = v);
                  },
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: TransactionFilter.all, child: Text('All')),
                    DropdownMenuItem(value: TransactionFilter.pending, child: Text('Pending')),
                    DropdownMenuItem(value: TransactionFilter.topups, child: Text('Top-ups')),
                    DropdownMenuItem(value: TransactionFilter.deductions, child: Text('Deductions')),
                  ],
                ),
              ),
            ],
          ),
          body: ref.watch(parentTransactionsStreamProvider(parentId)).when(
            data: (transactions) {
              // apply client-side filtering based on _filter
              final filtered = transactions.where((tx) {
                final amount = tx.amount;
                final isTopup = amount > 0;
                final reason = tx.reason;
                final isDeferred = reason.toLowerCase().contains('deferred') || 
                    (tx.balanceBefore != null && tx.balanceAfter != null && 
                     tx.balanceBefore == tx.balanceAfter && reason.toLowerCase().contains('weekly'));
                switch (_filter) {
                  case TransactionFilter.all:
                    return true;
                  case TransactionFilter.pending:
                    return isDeferred;
                  case TransactionFilter.topups:
                    return isTopup;
                  case TransactionFilter.deductions:
                    return !isTopup && !isDeferred;
                }
              }).toList();
              
              if (filtered.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 72.sp, color: Theme.of(context).colorScheme.primary.withAlpha((0.15 * 255).round())),
                      SizedBox(height: 12.h),
                      Text('No transactions yet', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 8.h),
                      Text('Any wallet top-ups or purchases will appear here.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final tx = filtered[index];
                  final amount = tx.amount;
                  final isTopup = amount > 0;
                  final date = tx.createdAt;
                  final reason = tx.reason;
                  final orderIds = tx.orderIds.join(', ');

                  String description = reason;
                  final isDeferred = reason.toLowerCase().contains('deferred') || 
                      (tx.balanceBefore != null && tx.balanceAfter != null && 
                       tx.balanceBefore == tx.balanceAfter && reason.toLowerCase().contains('weekly'));
                  if (reason == 'weekly_order' && orderIds.isNotEmpty) {
                    description = 'Weekly Order ($orderIds)';
                  } else if (reason == 'weekly_order_deferred' || isDeferred) {
                    description = 'Weekly Order (Pending)';
                  } else if (reason == 'topup') {
                    description = 'Wallet Top-up';
                  }

                  return Card(
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      minVerticalPadding: 0,
                      visualDensity: VisualDensity.compact,
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(description),
                          content: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 400.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Amount: ${FormatUtils.currency(amount.abs())}'),
                                  SizedBox(height: 8.h),
                                  Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(date)}'),
                                  SizedBox(height: 8.h),
                                  if (orderIds.isNotEmpty) ...[
                                    Text('Order IDs:'),
                                    SizedBox(height: 6.h),
                                    Text(orderIds),
                                  ],
                                  if (tx.reason.isNotEmpty) ...[
                                    SizedBox(height: 8.h),
                                    Text('Note: ${tx.reason}'),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                          ],
                        ),
                      ),
                      leading: CircleAvatar(
                        radius: 22.sp,
                        backgroundColor: isTopup ? Colors.green.shade100 : (isDeferred ? Colors.amber.shade100 : Colors.red.shade100),
                        child: Icon(isTopup ? Icons.add : (isDeferred ? Icons.hourglass_top : Icons.remove), size: 20.sp, color: isTopup ? Colors.green : (isDeferred ? Colors.orange : Colors.red)),
                      ),
                      title: Text(description, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(date), style: Theme.of(context).textTheme.bodySmall),
                      trailing: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 72.w, maxWidth: 140.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${isTopup ? '+' : ''}${FormatUtils.currency(amount.abs())}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isTopup ? Colors.green : (isDeferred ? Colors.orange : Colors.red), fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isDeferred)
                              Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(color: Colors.orange.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.orange.withAlpha((0.25 * 255).round()))),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Pending', style: TextStyle(color: Colors.orange.shade700, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading transactions: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Error loading transactions')),
      ),
    );
  }
}
