import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_app/core/models/cart_item.dart';
import 'package:canteen_app/core/providers/weekly_cart_provider.dart';
import 'package:canteen_app/core/models/menu_item.dart';

/// Service that persists and restores daily and weekly carts to Supabase
/// using a compact JSON payload stored in `saved_carts` table.
class CartPersistenceService {
  final SupabaseClient supabase;
  CartPersistenceService({required this.supabase});

  // ---------- DAILY CART ----------
  Future<List<CartItem>> fetchDailyCart(String parentId) async {
    final res = await supabase
        .from('saved_carts')
        .select('daily_cart')
        .eq('parent_id', parentId)
        .maybeSingle();
    if (res == null) return [];
    final List data = (res['daily_cart'] as List?) ?? [];
    return data.map((e) => CartItem.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveDailyCart(String parentId, List<CartItem> items) async {
    final payload = {
      'parent_id': parentId,
      'daily_cart': items.map((e) => e.toMap()).toList(),
    };
    await supabase.from('saved_carts').upsert(payload, onConflict: 'parent_id');
  }

  // ---------- DAILY CART (normalized tables) ----------
  Future<List<CartItem>> fetchDailyCartFromTables(String parentId) async {
    // Get all active daily carts for this parent
  final carts = await supabase
        .from('carts')
        .select('id, student_id')
        .eq('parent_id', parentId)
        .eq('cart_type', 'daily')
        .eq('status', 'active');
  if ((carts as List).isEmpty) return [];

    final List<CartItem> result = [];
    for (final c in (carts as List)) {
      final cartId = c['id'] as String;
      final studentId = c['student_id'] as String?;
      final itemsRes = await supabase
          .from('cart_items')
          .select('id, item_id, quantity, added_at, menu_items ( id, name, description, price, category, image_url, created_at, updated_at )')
          .eq('cart_id', cartId);
      for (final row in (itemsRes as List)) {
        final menu = Map<String, dynamic>.from(row['menu_items'] as Map);
        result.add(CartItem(
          id: row['id'] as String,
          menuItemId: row['item_id'] as String,
          name: (menu['name'] ?? '') as String,
          imageUrl: menu['image_url'] as String?,
          price: (menu['price'] as num).toDouble(),
          quantity: (row['quantity'] as num).toInt(),
          category: (menu['category'] ?? 'Other') as String,
          addedAt: DateTime.parse(row['added_at'] as String),
          studentId: studentId,
          studentName: null,
          deliveryTime: null,
          specialInstructions: null,
        ));
      }
    }
    return result;
  }

  Future<void> saveDailyCartToTables(String parentId, List<CartItem> items) async {
    // Group by studentId (nullable items are skipped)
    final Map<String, List<CartItem>> byStudent = {};
    for (final it in items) {
      final sid = it.studentId;
      if (sid == null) continue;
      byStudent.putIfAbsent(sid, () => []);
      byStudent[sid]!.add(it);
    }

    for (final entry in byStudent.entries) {
      final studentId = entry.key;
      // Find or create cart
      final existing = await supabase
          .from('carts')
          .select('id')
          .eq('parent_id', parentId)
          .eq('student_id', studentId)
          .eq('cart_type', 'daily')
          .eq('status', 'active')
          .maybeSingle();
      String cartId;
      if (existing != null) {
        cartId = existing['id'] as String;
      } else {
        final inserted = await supabase
            .from('carts')
            .insert({
              'parent_id': parentId,
              'student_id': studentId,
              'cart_type': 'daily',
              'order_date': DateTime.now().toIso8601String(),
              'status': 'active',
            })
            .select('id')
            .single();
        cartId = inserted['id'] as String;
      }

      // Replace items: delete then insert
      await supabase.from('cart_items').delete().eq('cart_id', cartId);
      if (entry.value.isNotEmpty) {
        final rows = entry.value.map((e) => {
              'cart_id': cartId,
              'item_id': e.menuItemId,
              'quantity': e.quantity,
              'added_at': e.addedAt.toIso8601String(),
            });
        await supabase.from('cart_items').insert(rows.toList());
      }
    }
  }

  // ---------- WEEKLY CART ----------
  // We persist as a flat list of items with an explicit `date` field (ISO8601),
  // and nested minimal menu_item data so UI can reconstruct MenuItem.
  Future<Map<DateTime, List<WeeklyCartItem>>> fetchWeeklyCart(String parentId) async {
    final res = await supabase
        .from('saved_carts')
        .select('weekly_cart')
        .eq('parent_id', parentId)
        .maybeSingle();
    if (res == null) return {};
    final List data = (res['weekly_cart'] as List?) ?? [];
    final Map<DateTime, List<WeeklyCartItem>> result = {};
    for (final raw in data) {
      final m = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.parse(m['date'] as String);
      final menu = Map<String, dynamic>.from(m['menu_item'] as Map);
      // Fill minimal fields for MenuItem
      final menuItem = MenuItem.fromMap({
        'id': menu['id'],
        'name': menu['name'] ?? '',
        'description': menu['description'] ?? '',
        'price': (menu['price'] as num).toDouble(),
        'category': menu['category'] ?? 'Other',
        'image_url': menu['image_url'],
        'allergens': menu['allergens'] ?? <String>[],
        'dietary_labels': menu['dietary_labels'] ?? <String>[],
        'is_available': menu['is_available'] ?? true,
        'prep_time_minutes': menu['prep_time_minutes'],
        'created_at': (menu['created_at'] ?? DateTime.now().toIso8601String()),
        'updated_at': menu['updated_at'],
      });
      final item = WeeklyCartItem(
        id: m['id'] as String,
        menuItem: menuItem,
        date: DateTime(date.year, date.month, date.day),
        quantity: m['quantity'] as int,
        addedAt: DateTime.parse(m['added_at'] as String),
        studentId: m['student_id'] as String?,
        studentName: m['student_name'] as String?,
        mealType: m['meal_type'] as String?,
        time: m['time'] as String?,
      );
      final key = DateTime(item.date.year, item.date.month, item.date.day);
      result.putIfAbsent(key, () => []);
      result[key]!.add(item);
    }
    return result;
  }

  Future<void> saveWeeklyCart(String parentId, Map<DateTime, List<WeeklyCartItem>> data) async {
    final List<Map<String, dynamic>> flat = [];
    for (final entry in data.entries) {
      for (final item in entry.value) {
        flat.add({
          'id': item.id,
          'date': DateTime(entry.key.year, entry.key.month, entry.key.day).toIso8601String(),
          'quantity': item.quantity,
          'added_at': item.addedAt.toIso8601String(),
          'student_id': item.studentId,
          'student_name': item.studentName,
          'meal_type': item.mealType,
          'time': item.time,
          'menu_item': {
            'id': item.menuItem.id,
            'name': item.menuItem.name,
            'description': item.menuItem.description,
            'price': item.menuItem.price,
            'category': item.menuItem.category,
            'image_url': item.menuItem.imageUrl,
            'allergens': item.menuItem.allergens,
            'dietary_labels': item.menuItem.dietaryLabels,
            'is_available': item.menuItem.isAvailable,
            'prep_time_minutes': item.menuItem.prepTimeMinutes,
            'created_at': item.menuItem.createdAt.toIso8601String(),
            'updated_at': item.menuItem.updatedAt?.toIso8601String(),
          },
        });
      }
    }
    final payload = {
      'parent_id': parentId,
      'weekly_cart': flat,
    };
    await supabase.from('saved_carts').upsert(payload, onConflict: 'parent_id');
  }
}
