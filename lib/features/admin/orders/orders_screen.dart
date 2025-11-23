import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/order.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/extensions/list_extensions.dart';
import '../../../shared/components/loading_indicator.dart';
import 'order_details_screen.dart';

/// Admin Orders Management Screen
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 0;
      });
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedStatus = null;
      _startDate = null;
      _endDate = null;
      _currentPage = 0;
    });
  }

  List<Order> _filterOrders(List<Order> orders) {
    return orders.where((order) {
      // Status filter
      if (_selectedStatus != null && order.status.name != _selectedStatus) {
        return false;
      }

      // Date range filter
      if (_startDate != null && order.deliveryDate.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && order.deliveryDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.updateOrderStatus(order.id, newStatus.name);

      if (!mounted) return;
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

  void _showStatusUpdateDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Order #${order.orderNumber}'),
            const SizedBox(height: 16),
            ...OrderStatus.values
                .where((status) => status != order.status && status != OrderStatus.cancelled)
                .map((status) => ListTile(
                      title: Text(status.displayName),
                      onTap: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order, status);
                      },
                    )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final studentsAsync = ref.watch(studentsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: isMobile ? 24 : 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Orders Management',
                    style: (isMobile ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Search by order number or student name
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by order # or student...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),

                // Status Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                      ...OrderStatus.values.map((status) =>
                          DropdownMenuItem<String?>(
                            value: status.name,
                            child: Text(status.displayName),
                          )),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedStatus = value;
                        _currentPage = 0;
                      });
                    },
                  ),
                ),

                // Date Range
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                        : 'Date Range',
                  ),
                ),

                // Clear Filters
                if (_searchQuery.isNotEmpty || _selectedStatus != null || _startDate != null)
                  OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Orders Table
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: LoadingIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error loading orders: $error'),
                ),
                data: (orders) {
                  // Filter by search query
                  var filtered = orders.where((order) {
                    if (_searchQuery.isEmpty) return true;
                    return order.orderNumber.toLowerCase().contains(_searchQuery) ||
                        order.studentId.toLowerCase().contains(_searchQuery);
                  }).toList();

                  // Apply date and status filters
                  filtered = _filterOrders(filtered);

                  // Sort by created date descending
                  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No orders found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  // Pagination
                  final totalPages = (filtered.length / _rowsPerPage).ceil();
                  final startIdx = _currentPage * _rowsPerPage;
                  final endIdx = (startIdx + _rowsPerPage).clamp(0, filtered.length);
                  final pageOrders = filtered.sublist(startIdx, endIdx);

                  return Column(
                    children: [
                      // Data Table
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateColor.resolveWith(
                                (states) => Theme.of(context).colorScheme.primaryContainer,
                              ),
                              columns: [
                                const DataColumn(label: Text('Order #')),
                                const DataColumn(label: Text('Student')),
                                const DataColumn(label: Text('Parent')),
                                const DataColumn(label: Text('Items')),
                                const DataColumn(label: Text('Amount')),
                                const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('Delivery')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: pageOrders.map((order) {
                                // Resolve student name
                                String studentName = 'Unknown';
                                studentsAsync.maybeWhen(
                                  data: (students) {
                                    final student = students.firstWhereOrNull((s) => s.id == order.studentId);
                                    if (student != null) {
                                      studentName = '${student.firstName} ${student.lastName}';
                                    }
                                  },
                                  orElse: () {},
                                );

                                return DataRow(
                                  onSelectChanged: (_) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OrderDetailsScreen(orderId: order.id),
                                      ),
                                    );
                                  },
                                  cells: [
                                    DataCell(Text(order.orderNumber)),
                                    DataCell(Text(studentName)),
                                    DataCell(_ParentNameCell(parentId: order.parentId)),
                                    DataCell(Text('${order.items.length}')),
                                    DataCell(Text('₱${order.totalAmount.toStringAsFixed(2)}')),
                                    DataCell(_buildStatusChip(order.status)),
                                    DataCell(Text(DateFormat('MMM d, yyyy').format(order.deliveryDate))),
                                    DataCell(
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'view') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => OrderDetailsScreen(orderId: order.id),
                                              ),
                                            );
                                          } else if (value == 'status') {
                                            _showStatusUpdateDialog(order);
                                          } else if (value == 'cancel') {
                                            _cancelOrder(order);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                          if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled)
                                            const PopupMenuItem<String>(
                                              value: 'status',
                                              child: Text('Update Status'),
                                            ),
                                          const PopupMenuItem<String>(
                                            value: 'view',
                                            child: Text('View Details'),
                                          ),
                                          if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled)
                                            const PopupMenuItem<String>(
                                              value: 'cancel',
                                              child: Text('Cancel Order'),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                      // Pagination Controls
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Page ${_currentPage + 1} of $totalPages (${filtered.length} orders)',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                  ),
                                  ...List.generate(
                                    totalPages,
                                    (index) => OutlinedButton(
                                      onPressed: () => setState(() => _currentPage = index),
                                      style: _currentPage == index
                                          ? OutlinedButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                            )
                                          : null,
                                      child: Text('${index + 1}'),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget to display parent name by resolving user info
class _ParentNameCell extends ConsumerWidget {
  final String parentId;

  const _ParentNameCell({required this.parentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(parentId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const Text('Unknown');
        return Text('${user.firstName} ${user.lastName}');
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => const Text('Error'),
    );
  }
}