import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/format_utils.dart';

/// Orders Screen - View and manage orders for linked students
/// 
/// Features:
/// - Display daily and weekly orders per student
/// - Show order status (Pending, Confirmed, Served, Cancelled)
/// - Allow editing/cancellation of unserved orders
/// - Provide order history with spending totals
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(parentStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.access_time)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return _buildEmptyState(
              icon: Icons.person_add_outlined,
              title: 'No Students Linked',
              message: 'Link your children to view their orders',
              actionLabel: 'Link Student',
              onAction: () {
                // TODO: Navigate to student linking screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student linking coming soon'),
                  ),
                );
              },
            );
          }

          // Set default selected student if not set
          if (_selectedStudentId == null && students.isNotEmpty) {
            _selectedStudentId = students.first.id;
          }

          return Column(
            children: [
              // Student selector
              _buildStudentSelector(students),
              // Orders list
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveOrders(),
                    _buildOrderHistory(),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  /// Build student selector chips
  Widget _buildStudentSelector(List<Student> students) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Student',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: students.map((student) {
                final isSelected = student.id == _selectedStudentId;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(student.fullName),
                    avatar: CircleAvatar(
                      backgroundImage: student.photoUrl != null
                          ? NetworkImage(student.photoUrl!)
                          : null,
                      child: student.photoUrl == null
                          ? Text(student.firstName[0])
                          : null,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedStudentId = student.id;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build active orders list
  Widget _buildActiveOrders() {
    if (_selectedStudentId == null) {
      return const Center(child: Text('Please select a student'));
    }

    final ordersAsync = ref.watch(
      studentOrdersProvider(_selectedStudentId!),
    );

    return ordersAsync.when(
      data: (orders) {
        // Filter active orders
        final activeOrders = orders.where((order) {
          return order.status != OrderStatus.completed &&
              order.status != OrderStatus.cancelled;
        }).toList();

        if (activeOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Active Orders',
            message: 'You don\'t have any pending orders',
            actionLabel: 'Browse Menu',
            onAction: () {
              // Navigate to menu screen
              Navigator.of(context).pushNamed('/parent-menu');
            },
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(activeOrders[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  /// Build order history list
  Widget _buildOrderHistory() {
    if (_selectedStudentId == null) {
      return const Center(child: Text('Please select a student'));
    }

    final ordersAsync = ref.watch(
      studentOrdersProvider(_selectedStudentId!),
    );

    return ordersAsync.when(
      data: (orders) {
        // Filter completed/cancelled orders
        final historyOrders = orders.where((order) {
          return order.status == OrderStatus.completed ||
              order.status == OrderStatus.cancelled;
        }).toList();

        if (historyOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No Order History',
            message: 'Your completed orders will appear here',
            actionLabel: 'Browse Menu',
            onAction: () {
              // Navigate to menu screen
            },
          );
        }

        // Calculate total spending
        final totalSpending = historyOrders
            .where((o) => o.status == OrderStatus.completed)
            .fold<double>(0, (sum, order) => sum + order.totalAmount);

        return Column(
          children: [
            // Total spending card
            Container(
              margin: EdgeInsets.all(16.w),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Spending',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${historyOrders.length} orders',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          Text(
          FormatUtils.currency(totalSpending),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
                ],
              ),
            ),
            // Orders list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: historyOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(historyOrders[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  /// Build order card widget
  Widget _buildOrderCard(Order order) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    dateFormat.format(order.orderDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(width: 16.w),
                  Icon(Icons.access_time, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    timeFormat.format(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    FormatUtils.currency(order.totalAmount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              if (order.status == OrderStatus.pending) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelOrder(order),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build status chip
  Widget _buildStatusChip(OrderStatus status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.schedule;
        break;
      case OrderStatus.confirmed:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.preparing:
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
        icon = Icons.kitchen_outlined;
        break;
      case OrderStatus.ready:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.done_all;
        break;
      case OrderStatus.completed:
        backgroundColor = Colors.teal.shade100;
        textColor = Colors.teal.shade900;
        icon = Icons.check_circle;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.cancel;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16.sp, color: textColor),
      label: Text(
        status.displayName,
        style: TextStyle(color: textColor, fontSize: 12.sp),
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }

  /// Show order details bottom sheet
  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Order info
                        _buildDetailRow('Order ID', order.id.substring(0, 12).toUpperCase()),
                        _buildDetailRow('Student', order.studentName),
                        _buildDetailRow(
                          'Date',
                          DateFormat('MMM dd, yyyy').format(order.orderDate),
                        ),
                        _buildDetailRow('Status', order.status.displayName),
                        Divider(height: 24.h),
                        // Order items
                        Text(
                          'Items',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: 8.h),
                        ...order.items.map((item) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text('${item.quantity}x'),
                            ),
                            title: Text(item.menuItemName),
                            subtitle: Text('${FormatUtils.currency(item.price)} each'),
                            trailing: Text(
                              FormatUtils.currency(item.total),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        }),
                        Divider(height: 24.h),
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              FormatUtils.currency(order.totalAmount),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Cancel order
  void _cancelOrder(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Implement order cancellation
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order cancellation coming soon')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 24.h),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80.sp, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'Error Loading Orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
