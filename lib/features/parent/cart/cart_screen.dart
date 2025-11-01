// ignore_for_file: use_build_context_synchronously

import '../../../core/providers/active_student_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/order.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';
import 'package:canteen_app/features/parent/cart/widgets/student_selection_dialog.dart';
import '../../../core/exceptions/app_exceptions.dart';

/// Cart Screen - Display and manage shopping cart
/// 
/// Features:
/// - View all cart items
/// - Update quantities
/// - Remove items
/// - See total price
/// - Proceed to checkout
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(parentStudentsProvider);
    final students = studentsAsync.value ?? [];
    final activeStudent = ref.watch(activeStudentProvider);
    final cart = ref.watch(cartProvider).where((item) => activeStudent == null || item.studentId == activeStudent.id).toList();
    final total = cart.fold(0.0, (sum, item) => sum + item.total);
    final isEmpty = cart.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cart', style: TextStyle(fontSize: 20.sp)),
            if (activeStudent != null)
              Text(activeStudent.fullName, style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearCartDialog(context, ref),
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          SizedBox(width: 8.w),
        ],
      ),

      body: SafeArea(
        child: isEmpty
            ? _buildEmptyCart(context)
            : _buildCartList(context, ref, cart),
      ),
      bottomNavigationBar: isEmpty
          ? null
          : _buildCheckoutBar(context, ref, total),
      floatingActionButton: students.length > 1
          ? FloatingActionButton.extended(
              icon: Icon(Icons.switch_account),
              label: Text('Switch Student'),
              onPressed: () async {
                final selected = await showModalBottomSheet<Student>(
                  context: context,
                  builder: (context) {
                    return ListView(
                      children: students.map((student) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
                          child: student.photoUrl == null ? Text(student.firstName[0].toUpperCase()) : null,
                        ),
                        title: Text(student.fullName),
                        subtitle: Text(student.grade),
                        selected: activeStudent?.id == student.id,
                        onTap: () => Navigator.pop(context, student),
                      )).toList(),
                    );
                  },
                );
                if (selected != null) {
                  ref.read(activeStudentProvider.notifier).state = selected;
                }
              },
            )
          : null,
    );
  }

  /// Empty cart state
  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add items from the menu to get started',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Browse Menu'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }

  /// Cart items list
  Widget _buildCartList(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        return _buildCartItemCard(context, ref, item);
      },
    );
  }

  /// Individual cart item card
  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, CartItem item) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            _buildItemImage(item),
            
            SizedBox(width: 12.w),
            
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and remove button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        iconSize: 20.sp,
                        color: Colors.grey[600],
                        onPressed: () => _removeItem(context, ref, item),
                        tooltip: 'Remove item',
                        constraints: BoxConstraints(
                          minWidth: 32.w,
                          minHeight: 32.h,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 4.h),
                  
                  // Category badge
                  Container(
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
                  
                  // Price and quantity controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FormatUtils.currency(item.price),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
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
                      
                      // Quantity controls
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
  }

  /// Item image thumbnail
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
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.w),
                  ),
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

  /// Quantity increment/decrement controls
  Widget _buildQuantityControls(BuildContext context, WidgetRef ref, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement button
          InkWell(
            onTap: () {
              if (item.quantity > 1) {
                ref.read(cartProvider.notifier).decrementQuantity(item.id);
              } else {
                _removeItem(context, ref, item);
              }
            },
            borderRadius: BorderRadius.horizontal(left: Radius.circular(8.r)),
            child: Container(
              width: 36.w,
              height: 36.h,
              alignment: Alignment.center,
              child: Icon(
                item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 18.sp,
                color: item.quantity > 1 ? Colors.grey[700] : Colors.red,
              ),
            ),
          ),
          
          // Quantity display
          Container(
            width: 40.w,
            height: 36.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Increment button
          InkWell(
            onTap: () {
              if (item.quantity < 10) {
                ref.read(cartProvider.notifier).incrementQuantity(item.id);
              }
            },
            borderRadius: BorderRadius.horizontal(right: Radius.circular(8.r)),
            child: Container(
              width: 36.w,
              height: 36.h,
              alignment: Alignment.center,
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

  /// Checkout bar at the bottom
  Widget _buildCheckoutBar(BuildContext context, WidgetRef ref, double total) {
    final itemCount = ref.watch(cartItemCountProvider);
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ($itemCount ${itemCount == 1 ? 'item' : 'items'})',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
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
                
                // Checkout button
                ElevatedButton(
                  onPressed: () => _handleCheckout(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined),
                      SizedBox(width: 8.w),
                      Text(
                        'Checkout',
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
          ],
        ),
      ),
    );
  }

  /// Remove item from cart with confirmation
  void _removeItem(BuildContext context, WidgetRef ref, CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.name} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).removeItem(item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} removed from cart'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Show clear cart confirmation dialog
  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cart cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Handle checkout process
  Future<void> _handleCheckout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    // Capture NavigatorState before any await to safely use it after async gaps
    final navigator = Navigator.of(context);
    
    // Get linked students
    final studentsAsync = ref.read(parentStudentsProvider);
    final students = studentsAsync.value ?? [];
    
    if (students.isEmpty) {
      // We intentionally use the captured navigator.context here because
      // this method may continue across async gaps and navigator was
      // captured before any await.
      _showErrorDialog(
        navigator.context,
        'No Linked Students',
        'Please link at least one student to place an order.',
      );
      return;
    }
    
  // Show shared student selection dialog to select student and confirm
  final selectedList = await showStudentSelectionDialog(navigator.context, ref, orderTotal: total);
  final selectedStudent = (selectedList == null || selectedList.isEmpty) ? null : selectedList.first;
    
    if (selectedStudent == null) return; // User cancelled
    
    // Verify parent wallet balance (students are imported entities; parents pay)
    final currentUserId = ref.read(currentUserProvider).value?.uid;
    if (currentUserId == null) {
      _showErrorDialog(
        navigator.context,
        'Not Signed In',
        'Unable to identify parent account. Please sign in and try again.',
      );
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
    
    // Show loading dialog
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
    
    try {

      // Create order
      final order = Order(
        id: const Uuid().v4(),
        studentId: selectedStudent.id,
        studentName: selectedStudent.fullName,
        parentId: ref.read(currentUserProvider).value?.uid,
        items: cart.map((cartItem) => OrderItem(
          menuItemId: cartItem.id,
          menuItemName: cartItem.name,
          price: cartItem.price,
          quantity: cartItem.quantity,
        )).toList(),
        totalAmount: total,
        status: OrderStatus.pending,
        orderDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      
      // Place order and deduct parent balance using services
      final orderService = ref.read(orderServiceProvider);
      final parentService = ref.read(parentServiceProvider);
      final currentUserId = ref.read(currentUserProvider).value!.uid;
      
      try {
        // Get current parent balance
        final parent = await parentService.getParentById(currentUserId);
        final currentBalance = parent?.balance ?? 0.0;
        
        if (currentBalance < total) {
          throw Exception('Insufficient wallet balance');
        }
        
        // Create order
        await orderService.createOrder(order);
        
        // Deduct balance and record transaction
        final newBalance = currentBalance - total;
        await parentService.updateBalance(currentUserId, newBalance);
        await parentService.recordTransaction(
          parentId: currentUserId,
          amount: -total,
          balanceBefore: currentBalance,
          balanceAfter: newBalance,
          orderIds: [order.id],
          reason: 'single_order',
        );
      } catch (e) {
        // If any step fails, the order won't be created or balance won't be deducted
        rethrow;
      }

      // Clear cart
      ref.read(cartProvider.notifier).clear();

      // Close loading dialog using captured navigator
      navigator.pop();

      // Show success dialog using a safe context (navigator.context)
      await _showSuccessDialog(navigator.context, order, selectedStudent);

      // Navigate back to menu
      navigator.pop();
    } catch (e) {
      // Close loading dialog using captured navigator if possible
      try {
        Navigator.of(navigator.context, rootNavigator: true).pop();
      } catch (_) {}

      // Show error using captured navigator.context to avoid using
      // the original BuildContext after async gaps.
      _showErrorDialog(
        navigator.context,
        'Order Failed',
        e is AppException ? e.message : 'Failed to place order: $e',
      );
    }
  }
  
  /// Show checkout dialog with student selection
  // Checkout dialog is provided via shared widget showStudentSelectionDialog
  
  /// Show success dialog
  Future<void> _showSuccessDialog(
    BuildContext context,
    Order order,
    Student student,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.green[700],
          size: 48.sp,
        ),
        title: const Text('Order Placed Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order for ${student.fullName}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            _buildOrderDetailRow('Order ID:', order.id.substring(0, 8).toUpperCase()),
            _buildOrderDetailRow('Items:', '${order.items.length}'),
            _buildOrderDetailRow('Total:', FormatUtils.currency(order.totalAmount)),
            _buildOrderDetailRow('Status:', order.status.displayName),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20.sp,
                    color: Colors.green[700],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Your order will be prepared for pickup',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show error dialog
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: Colors.red[700],
          size: 48.sp,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
