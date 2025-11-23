import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/user_providers.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/models/topup.dart';
import 'transactions_screen.dart';
import '../../../core/providers/date_refresh_provider.dart';

/// Wallet Screen - Manage parent wallet and (admin) student balances
/// 
/// Features:
/// - Display parent wallet balance (this is the authoritative balance used for billing)
/// - Show individual student balances (display-only; student.balance is admin/reference-only)
/// - Top-up functionality (mock for now)
/// - Transaction history
/// - Auto-deduct on confirmed orders (deductions apply to parent wallet)
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  // filters removed; navigation to full transactions screen via View All

  @override
  Widget build(BuildContext context) {
    // Watch dateRefreshProvider to ensure rebuild when date changes
    ref.watch(dateRefreshProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () => _showTopUpDialog(context),
            icon: const Icon(Icons.add_card),
            tooltip: 'Top Up',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Parent wallet balance card
            _buildParentWalletCard(context),
            SizedBox(height: 16.h),
            SizedBox(height: 16.h),
            // Transaction history
            _buildTransactionHistory(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTopUpDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Top Up'),
      ),
    );
  }

  /// Build parent wallet balance card
  Widget _buildParentWalletCard(BuildContext context) {
    final parentAsync = ref.watch(currentParentProvider);
    return parentAsync.when(
      data: (parent) {
        final parentBalance = parent?.balance ?? 0.0;
        return Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withAlpha((0.3 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parent Wallet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    size: 32.sp,
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                'Available Balance',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                FormatUtils.currency(parentBalance),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  _buildWalletStat(
                    context,
                    icon: Icons.trending_up,
                    label: 'This Month',
                    value: FormatUtils.currency(1250),
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                  ),
                  SizedBox(width: 24.w),
                  _buildWalletStat(
                    context,
                    icon: Icons.receipt_long,
                    label: 'Orders',
                    value: '24',
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error loading balance'),
    );
  }

  Widget _buildWalletStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: color),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // Student balances removed per user request

  /// Build transaction history
  Widget _buildTransactionHistory(BuildContext context) {
    final parentAsync = ref.watch(currentParentProvider);
    return parentAsync.when(
      data: (parent) {
        final parentId = parent?.userId;
        if (parentId == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No parent profile found.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Make the title flexible so it can truncate instead of causing overflow
                  Expanded(
                    child: Text(
                      'Transaction History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 'View All' navigates to the full transactions screen
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            // Stream parent_transactions for this parent, ordered by createdAt desc
            SizedBox(
              // limit the height to allow pull-to-refresh to work naturally inside scroll
              child: ref.watch(parentTransactionsStreamProvider(parentId)).when(
                data: (transactions) {
                  // Friendly empty state
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                      child: Column(
                        children: [
                          SizedBox(height: 8.h),
                          // simple illustration placeholder
                          SizedBox(
                            height: 140.h,
                            child: Icon(Icons.receipt_long, size: 72.sp, color: Theme.of(context).colorScheme.primary.withAlpha((0.15 * 255).round())),
                          ),
                          SizedBox(height: 12.h),
                                          Text('No transactions yet', style: Theme.of(context).textTheme.titleMedium),
                                          SizedBox(height: 8.h),
                                          Text('Any wallet top-ups or purchases will appear here.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                                          SizedBox(height: 16.h),
                                          FilledButton.tonal(
                                            onPressed: () => _showTopUpDialog(context),
                                            child: const Text('Top Up Wallet'),
                                          ),
                        ],
                      ),
                    );
                  }

                  // Show top 5 transactions
                  final limitedTransactions = transactions.take(5).toList();

                  // Animated switcher for smoother transitions
                  return RefreshIndicator(
                    onRefresh: () async {
                      // simple refresh: rebuild stream by calling setState
                      setState(() {});
                      await Future.delayed(const Duration(milliseconds: 300));
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ListView.builder(
                        key: ValueKey(limitedTransactions.length),
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: limitedTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = limitedTransactions[index];
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
                              onTap: () {
                                // Show details dialog
                                showDialog(
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
                                );
                              },
                              leading: CircleAvatar(
                                radius: 22.sp,
                                backgroundColor: isTopup ? Colors.green.shade100 : (isDeferred ? Colors.amber.shade100 : Colors.red.shade100),
                                child: Icon(isTopup ? Icons.add : (isDeferred ? Icons.hourglass_top : Icons.remove), size: 20.sp, color: isTopup ? Colors.green : (isDeferred ? Colors.orange : Colors.red)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      description,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(DateFormat('MMM dd, yyyy').format(date), style: Theme.of(context).textTheme.bodySmall),
                              trailing: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: 72.w, maxWidth: 120.w),
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
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Error loading transactions', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 8.h),
                      Text(error.toString(), style: TextStyle(color: Colors.redAccent)),
                      SizedBox(height: 12.h),
                      ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error loading transactions'),
    );
  }

  /// Show top-up dialog
  void _showTopUpDialog(BuildContext context) {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Request Top-Up'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: AppConstants.currencySymbol,
                    border: const OutlineInputBorder(),
                    hintText: '0.00',
                  ),
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<PaymentMethod>(
                  value: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(),
                  ),
                  items: PaymentMethod.values.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedMethod = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Receipt number, confirmation code',
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Add any additional information',
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Your top-up request will be reviewed by an admin and processed within 24 hours.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                final reference = referenceController.text.trim();
                final notes = notesController.text.trim();

                try {
                  // Get current user info
                  final currentUser = ref.read(currentUserProvider).value;
                  final parent = ref.read(currentParentProvider).value;
                  
                  if (currentUser == null || parent == null) {
                    throw Exception('User not logged in');
                  }

                  // Create top-up request
                  final topup = Topup(
                    id: const Uuid().v4(),
                    parentId: parent.userId,
                    parentName: '${currentUser.firstName} ${currentUser.lastName}',
                    amount: amount,
                    status: TopupStatus.pending,
                    paymentMethod: selectedMethod,
                    transactionReference: reference.isEmpty ? null : reference,
                    notes: notes.isEmpty ? null : notes,
                    requestDate: DateTime.now(),
                    createdAt: DateTime.now(),
                  );

                  await ref.read(topupServiceProvider).createTopup(topup);

                  // Invalidate transactions provider to refresh UI immediately
                  ref.invalidate(parentTransactionsStreamProvider(topup.parentId));

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Top-up request submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
