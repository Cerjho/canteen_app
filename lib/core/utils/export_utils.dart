import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/order.dart' as app_models;
import 'format_utils.dart';

/// Export utilities for generating reports
class ExportUtils {
  /// Export orders to CSV
  static String exportOrdersToCSV(List<app_models.Order> orders) {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Order ID',
      'Date',
      'Student Name',
      'Items',
      'Total Amount',
      'Status',
    ]);

    // Data rows
    for (var order in orders) {
      rows.add([
        order.id,
        FormatUtils.dateTime(order.orderDate),
        order.studentName,
        order.items.map((item) => '${item.menuItemName} x${item.quantity}').join(', '),
        order.totalAmount,
        order.status.displayName,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Export orders to Excel
  static Uint8List exportOrdersToExcel(List<app_models.Order> orders) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Orders'];

    // Header
    sheet.appendRow([
      TextCellValue('Order ID'),
      TextCellValue('Date'),
      TextCellValue('Student Name'),
      TextCellValue('Items'),
      TextCellValue('Total Amount'),
      TextCellValue('Status'),
    ]);

    // Data rows
    for (var order in orders) {
      sheet.appendRow([
        TextCellValue(order.id),
        TextCellValue(FormatUtils.dateTime(order.orderDate)),
        TextCellValue(order.studentName),
        TextCellValue(order.items.map((item) => '${item.menuItemName} x${item.quantity}').join(', ')),
        DoubleCellValue(order.totalAmount),
        TextCellValue(order.status.displayName),
      ]);
    }

    // Save and return
    return Uint8List.fromList(excel.encode()!);
  }

  /// Export revenue report to CSV
  static String exportRevenueToCSV(
    List<app_models.Order> orders,
    DateTime startDate,
    DateTime endDate,
  ) {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'Revenue Report',
      FormatUtils.dateRange(startDate, endDate),
    ]);
    rows.add([]); // Empty row

    // Summary
    double totalRevenue = 0;
    int completedOrders = 0;
    int cancelledOrders = 0;

    for (var order in orders) {
      if (order.status == app_models.OrderStatus.completed) {
        totalRevenue += order.totalAmount;
        completedOrders++;
      } else if (order.status == app_models.OrderStatus.cancelled) {
        cancelledOrders++;
      }
    }

    rows.add(['Total Orders', orders.length]);
    rows.add(['Completed Orders', completedOrders]);
    rows.add(['Cancelled Orders', cancelledOrders]);
    rows.add(['Total Revenue', FormatUtils.currency(totalRevenue)]);
    rows.add(['Average Order Value', completedOrders > 0 ? FormatUtils.currency(totalRevenue / completedOrders) : '\$0.00']);
    rows.add([]); // Empty row

    // Detailed orders
    rows.add([
      'Order ID',
      'Date',
      'Student',
      'Items',
      'Amount',
      'Status',
    ]);

    for (var order in orders) {
      rows.add([
        order.id,
        FormatUtils.dateTime(order.orderDate),
        order.studentName,
        order.items.length,
        order.totalAmount,
        order.status.displayName,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
