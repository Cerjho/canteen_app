import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/models/student.dart';
import '../../../core/models/parent.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/extensions/list_extensions.dart';
import '../../../shared/components/loading_indicator.dart';

/// Admin Order Details Screen
class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  OrderStatus? _newStatus;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderByIdProvider(widget.orderId));
    final studentsAsync = ref.watch(studentsProvider);
    final parentsAsync = ref.watch(parentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(orderByIdProvider(widget.orderId));
            },
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading order: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Order not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            _buildStatusChip(order.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Date',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy - hh:mm a').format(order.createdAt),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Date',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy').format(order.deliveryDate),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (order.deliveryTime != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Time',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                                  ),
                                  Text(
                                    order.deliveryTime!,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Student & Parent Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student & Parent Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _StudentInfoWidget(studentId: order.studentId, studentsAsync: studentsAsync),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        _ParentInfoWidget(parentId: order.parentId, parentsAsync: parentsAsync),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Order Items
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order Items (${order.items.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...order.items.asMap().entries.map((entry) {
                          final item = entry.value;
                          return Column(
                            children: [
                              if (entry.key > 0) const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.menuItemName,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Qty: ${item.quantity}',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₱${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        '₱${item.total.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₱${order.totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Special Instructions
                if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Special Instructions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.specialInstructions!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Status Update Section
                if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Order Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<OrderStatus?>(
                            value: _newStatus,
                            decoration: const InputDecoration(
                              labelText: 'New Status',
                              border: OutlineInputBorder(),
                            ),
                            items: <DropdownMenuItem<OrderStatus?>>[
                              const DropdownMenuItem<OrderStatus?>(
                                value: null,
                                child: Text('Select a status...'),
                              ),
                              ...OrderStatus.values
                                  .where((status) => status != order.status && status != OrderStatus.cancelled)
                                  .map((status) => DropdownMenuItem<OrderStatus?>(
                                        value: status,
                                        child: Text(status.displayName),
                                      )),
                            ],
                            onChanged: (OrderStatus? value) {
                              setState(() => _newStatus = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _newStatus != null
                                    ? () => _updateStatus(order, _newStatus!)
                                    : null,
                                icon: const Icon(Icons.check),
                                label: const Text('Update Status'),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () => _cancelOrder(order),
                                icon: const Icon(Icons.cancel),
                                label: const Text('Cancel Order'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    final color = switch (status) {
      OrderStatus.pending => Colors.orange,
      OrderStatus.confirmed => Colors.blue,
      OrderStatus.preparing => Colors.purple,
      OrderStatus.ready => Colors.teal,
      OrderStatus.completed => Colors.green,
      OrderStatus.cancelled => Colors.red,
    };

    return Chip(
      label: Text(status.displayName),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
    );
  }

  Future<void> _updateStatus(Order order, OrderStatus newStatus) async {
    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.updateOrderStatus(order.id, newStatus.name);

      if (!mounted) return;
      setState(() => _newStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to ${newStatus.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order #${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final orderService = ref.read(orderServiceProvider);
        await orderService.cancelOrder(order.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling order: $e')),
        );
      }
    }
  }
}

class _StudentInfoWidget extends ConsumerWidget {
  final String studentId;
  final AsyncValue<List<Student>> studentsAsync;

  const _StudentInfoWidget({
    required this.studentId,
    required this.studentsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return studentsAsync.when(
      data: (students) {
        final student = students.firstWhereOrNull((s) => s.id == studentId);
        if (student == null) {
          return Text(
            'Student not found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Student',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${student.firstName} ${student.lastName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Grade: ${student.grade}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => Text(
        'Error loading student',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
      ),
    );
  }
}

class _ParentInfoWidget extends ConsumerWidget {
  final String parentId;
  final AsyncValue<List<Parent>> parentsAsync;

  const _ParentInfoWidget({
    required this.parentId,
    required this.parentsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(parentId));

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Text(
            'Parent not found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Parent/Guardian',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${user.firstName} ${user.lastName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.email,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => Text(
        'Error loading parent',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
      ),
    );
  }
}
