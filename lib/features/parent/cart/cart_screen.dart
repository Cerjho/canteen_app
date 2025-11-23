// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/order.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/date_refresh_provider.dart';
import '../../../core/providers/selected_student_provider.dart';
import '../../../core/providers/transaction_providers.dart';
import '../../../core/utils/format_utils.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStudentId = ref.watch(
      selectedStudentProvider.select((s) => s?.id),
    );
    final selectedStudentName = ref.watch(
      selectedStudentProvider.select((s) => s?.fullName),
    );

    final allItems = ref.watch(cartProvider);
    final items = allItems
        .where((item) => selectedStudentId == null || item.studentId == selectedStudentId)
        .toList();
    final total = items.fold<double>(0.0, (sum, i) => sum + i.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear cart',
              onPressed: () => _showClearCartDialog(context, ref),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(selectedStudentName == null ? 0 : 28.h),
          child: selectedStudentName == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    selectedStudentName,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                ),
        ),
      ),
      body: items.isEmpty
          ? _EmptyCart(selectedStudentName: selectedStudentName?.split(' ').first)
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildItemImage(item),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _removeItem(context, ref, item),
                                    tooltip: 'Remove',
                                  )
                                ],
                              ),
                              if (item.category.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: 4.h),
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              SizedBox(height: 8.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FormatUtils.currency(item.price),
                                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                                      ),
                                      Text(
                                        FormatUtils.currency(item.total),
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildQuantityControls(context, ref, item),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                      );
                    },
                  ),
                ),
                // Checkout bar as part of the Column, not bottomNavigationBar
                _buildCheckoutBar(context, ref, total),
              ],
            ),
    );
  }

  // Thumbnail
  Widget _buildItemImage(CartItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: SizedBox(
        width: 80.w,
        height: 80.h,
        child: item.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.w)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.restaurant_menu, size: 32.sp, color: Colors.grey[500]),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: Icon(Icons.restaurant_menu, size: 32.sp, color: Colors.grey[500]),
              ),
      ),
    );
  }

  // Quantity controls
  Widget _buildQuantityControls(BuildContext context, WidgetRef ref, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (item.quantity > 1) {
                ref.read(cartProvider.notifier).decrementQuantity(item.id);
              } else {
                _removeItem(context, ref, item);
              }
            },
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8.r)),
            child: SizedBox(
              width: 36.w,
              height: 36.h,
              child: Icon(
                item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 18.sp,
                color: item.quantity > 1 ? Colors.grey[700] : Colors.red,
              ),
            ),
          ),
          Container(
            width: 40.w,
            height: 36.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text('${item.quantity}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ),
          InkWell(
            onTap: () {
              if (item.quantity < 10) {
                ref.read(cartProvider.notifier).incrementQuantity(item.id);
              }
            },
            borderRadius: BorderRadius.horizontal(right: Radius.circular(8.r)),
            child: SizedBox(
              width: 36.w,
              height: 36.h,
              child: Icon(
                Icons.add,
                size: 18.sp,
                color: item.quantity < 10 ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Checkout bar
  Widget _buildCheckoutBar(BuildContext context, WidgetRef ref, double total) {
  final selectedStudentId = ref.watch(selectedStudentProvider.select((s) => s?.id));
  final itemCount = ref.watch(cartProvider)
    .where((i) => selectedStudentId == null || i.studentId == selectedStudentId)
        .fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: 12.h,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total ($itemCount ${itemCount == 1 ? 'item' : 'items'})',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 4.h),
                Text(
                  FormatUtils.currency(total),
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _handleCheckout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined),
                  SizedBox(width: 8.w),
                  Text('Checkout', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Remove single item
  void _removeItem(BuildContext context, WidgetRef ref, CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.name} from cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).removeItem(item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} removed from cart'), duration: const Duration(seconds: 2)),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Clear all items confirmation
  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared'), duration: Duration(seconds: 2)),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // Simplified checkout handler (single try-catch, uses selectedStudent + dateRefreshProvider)
  Future<void> _handleCheckout(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final selectedStudent = ref.read(selectedStudentProvider);
    final cart = ref.read(cartProvider);
    final items = cart.where((i) => selectedStudent == null || i.studentId == selectedStudent.id).toList();
    final total = items.fold<double>(0.0, (sum, i) => sum + i.total);

    // Early validations
    if (selectedStudent == null) {
      _showErrorDialog(navigator.context, 'No Student Selected', 'Please select a student from the Menu screen before checkout.');
      return;
    }

    final students = ref.read(parentStudentsProvider).value ?? [];
    if (students.isEmpty) {
      _showErrorDialog(navigator.context, 'No Linked Students', 'Please link at least one student to place an order.');
      return;
    }

    final currentUserId = ref.read(currentUserProvider).value?.uid;
    if (currentUserId == null) {
      _showErrorDialog(navigator.context, 'Not Signed In', 'Please sign in and try again.');
      return;
    }

    final parent = ref.read(currentParentProvider).value;
    final parentBalance = parent?.balance ?? 0.0;
    if (parentBalance < total) {
      _showErrorDialog(
        navigator.context,
        'Insufficient Wallet Balance',
        'Parent wallet (${FormatUtils.currency(parentBalance)}) is less than order total (${FormatUtils.currency(total)}).\n\nPlease top up the parent wallet first.',
      );
      return;
    }

    try {
      showDialog(
        context: navigator.context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Placing your order...'),
                ],
              ),
            ),
          ),
        ),
      );

      final orderItems = items
          .map((cartItem) => OrderItem(
                menuItemId: cartItem.menuItemId,
                menuItemName: cartItem.name,
                price: cartItem.price,
                quantity: cartItem.quantity,
              ).toMap())
          .toList();

      final orderService = ref.read(orderServiceProvider);
      final today = ref.read(dateRefreshProvider);
      final deliveryDate = DateTime(today.year, today.month, today.day);
      final createdOrderId = await orderService.placeOrder(
        parentId: currentUserId,
        studentId: selectedStudent.id,
        items: orderItems,
        totalAmount: total,
        deliveryDate: deliveryDate,
      );

      // Refresh dependent providers
      ref.invalidate(parentOrdersProvider);
      ref.invalidate(parentTransactionsStreamProvider(currentUserId));
      ref.invalidate(currentParentProvider);

  // Clear only items for this student via notifier API
  ref.read(cartProvider.notifier).removeItemsForStudent(selectedStudent.id);

      // Hide loading
      navigator.pop();

      // Success dialog
      await _showSuccessDialog(
        navigator.context,
        Order(
          id: createdOrderId,
          orderNumber: '',
          parentId: currentUserId,
          studentId: selectedStudent.id,
          items: orderItems.map(OrderItem.fromMap).toList(),
          totalAmount: total,
          status: OrderStatus.pending,
          orderType: OrderType.oneTime,
          deliveryDate: deliveryDate,
          createdAt: DateTime.now(),
        ),
        selectedStudent,
      );

      // Close cart
      navigator.pop();
    } catch (e) {
      try {
        Navigator.of(navigator.context, rootNavigator: true).pop();
      } catch (_) {}
      _showErrorDialog(navigator.context, 'Order Failed', e is AppException ? e.message : 'Failed to place order: $e');
    }
  }

  // Success dialog
  Future<void> _showSuccessDialog(BuildContext context, Order order, Student student) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle_outline, color: Colors.green[700], size: 48.sp),
        title: const Text('Order Placed Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order for ${student.fullName}',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            _buildOrderDetailRow('Order ID:', order.id.substring(0, 8).toUpperCase()),
            _buildOrderDetailRow('Items:', '${order.items.length}'),
            _buildOrderDetailRow('Total:', FormatUtils.currency(order.totalAmount)),
            _buildOrderDetailRow('Status:', order.status.displayName),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8.r)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20.sp, color: Colors.green[700]),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Your order will be prepared for pickup',
                      style: TextStyle(fontSize: 12.sp, color: Colors.green[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _buildOrderDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Generic error dialog
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error_outline, color: Colors.red[700], size: 48.sp),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final String? selectedStudentName;
  const _EmptyCart({this.selectedStudentName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              selectedStudentName == null
                  ? 'Your cart is empty'
                  : "${selectedStudentName!}'s cart is empty",
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

 
