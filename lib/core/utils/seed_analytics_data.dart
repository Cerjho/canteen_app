import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import 'app_logger.dart';

/// Utility class to seed test order data for analytics testing
class SeedAnalyticsData {
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  SeedAnalyticsData(this._supabase);

  /// Seed sample orders for analytics testing
  /// This creates realistic order data for the current week
  Future<void> seedOrdersForCurrentWeek(List<MenuItem> menuItems) async {
    try {
      AppLogger.info('🌱 Starting to seed analytics order data...');
      
      // Clear existing orders first to prevent duplicates
      AppLogger.info('🗑️ Clearing existing test orders...');
      await clearAllOrders();
      
      // Fetch real students from Firestore
      AppLogger.info('👥 Fetching students from Firestore...');
      final studentsData = await _supabase
          .from('students')
          .select('id, first_name, last_name');
      
      if (studentsData.isEmpty) {
        AppLogger.warning('⚠️ Warning: No students found. Please seed students first.');
        return;
      }
      
      // Extract student data
      final students = (studentsData as List).map((data) {
        return {
          'id': data['id'] as String,
          'name': '${data['first_name']} ${data['last_name']}',
        };
      }).toList();
      
      AppLogger.info('✅ Found ${students.length} students');
      
      // Get current week Monday
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      
      // Group menu items by category
      final snacks = menuItems.where((item) => item.category == 'Snack').toList();
      final lunches = menuItems.where((item) => item.category == 'Lunch').toList();
      final drinks = menuItems.where((item) => item.category == 'Drinks').toList();
      
      if (snacks.isEmpty || lunches.isEmpty || drinks.isEmpty) {
        AppLogger.warning('⚠️ Warning: Not enough menu items. Please seed menu items first.');
        return;
      }
      
      // Create orders for Monday to Friday
      int totalOrders = 0;
      for (int dayOffset = 0; dayOffset < 5; dayOffset++) {
        final orderDate = monday.add(Duration(days: dayOffset));
        final dayName = _getDayName(orderDate.weekday);
        
        AppLogger.info('📅 Creating orders for $dayName...');
        
        // Create 20-30 orders per day with varying patterns
        final ordersForDay = 20 + (dayOffset * 2); // Gradually increase through week
        
        for (int i = 0; i < ordersForDay; i++) {
          final orderId = _uuid.v4();
          
          // Use real student data (cycle through all students)
          final student = students[i % students.length];
          final studentId = student['id'] as String;
          final studentName = student['name'] as String;
          
          // Create order items with realistic patterns
          final orderItems = <Map<String, dynamic>>[];
          
          // Most students order 1-2 snacks
          final snackCount = (i % 3 == 0) ? 2 : 1;
          for (int j = 0; j < snackCount; j++) {
            final snack = snacks[i % snacks.length];
            orderItems.add({
              'menuItemId': snack.id,
              'menuItemName': snack.name,
              'mealType': 'snack',
              'quantity': 1,
              'price': snack.price,
            });
          }
          
          // 70% of students order lunch
          if (i % 10 < 7) {
            final lunch = lunches[i % lunches.length];
            orderItems.add({
              'menuItemId': lunch.id,
              'menuItemName': lunch.name,
              'mealType': 'lunch',
              'quantity': 1,
              'price': lunch.price,
            });
          }
          
          // 80% of students order drinks
          if (i % 10 < 8) {
            final drink = drinks[i % drinks.length];
            orderItems.add({
              'menuItemId': drink.id,
              'menuItemName': drink.name,
              'mealType': 'drinks',
              'quantity': 1,
              'price': drink.price,
            });
          }
          
          // Calculate total
          final totalAmount = orderItems.fold<double>(
            0, 
            (sum, item) => sum + (item['price'] as double) * (item['quantity'] as int)
          );
          
          // Create order document
          final orderData = {
            'id': orderId,
            'student_id': studentId,
            'student_name': studentName,
            'order_date': orderDate.toIso8601String(),
            'items': orderItems,
            'total_amount': totalAmount,
            'status': 'completed',
            'created_at': orderDate.toIso8601String(),
          };
          
          await _supabase.from('orders').insert(orderData);
          totalOrders++;
        }
        
        AppLogger.info('✅ Created $ordersForDay orders for $dayName');
      }
      
      AppLogger.info('✨ Successfully seeded $totalOrders orders for the current week!');
      AppLogger.info('📊 Now you can test analytics by:');
      AppLogger.info('   1. Go to Menu Management → Analytics tab');
      AppLogger.info('   2. Click "Refresh" to calculate analytics');
      AppLogger.info('   3. View charts, popular items, and trends');
      
    } catch (e) {
      AppLogger.error('❌ Error seeding analytics data', error: e);
      rethrow;
    }
  }
  
  /// Clear all test orders (use with caution!)
  Future<void> clearAllOrders() async {
    try {
      AppLogger.info('🗑️ Clearing all orders...');
      final ordersData = await _supabase.from('orders').select('id');
      final orderIds = (ordersData as List).map((order) => order['id'] as String).toList();
      
      if (orderIds.isNotEmpty) {
        await _supabase.from('orders').delete().inFilter('id', orderIds);
      }
      
      AppLogger.info('✅ Cleared ${orderIds.length} orders');
    } catch (e) {
      AppLogger.error('❌ Error clearing orders', error: e);
      rethrow;
    }
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }
}
