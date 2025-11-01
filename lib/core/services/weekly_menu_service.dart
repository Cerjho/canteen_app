import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/weekly_menu.dart';
import '../models/menu_item.dart';
import '../constants/database_constants.dart';
import '../interfaces/i_weekly_menu_service.dart';

/// Weekly Menu Service - handles all WeeklyMenu-related Firestore operations
class WeeklyMenuService implements IWeeklyMenuService {
  final SupabaseClient _supabase;
  final Uuid _uuid;

  /// Constructor with dependency injection
  WeeklyMenuService({
    SupabaseClient? supabase,
    Uuid? uuid,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _uuid = uuid ?? const Uuid();

  /// Get the current week's menu (or most recent published menu)
  @override
  Stream<WeeklyMenu?> getCurrentWeeklyMenu() {
    final today = DateTime.now();
    final mondayOfWeek = _getMondayOfWeek(today);
    final weekStartDate = _formatDate(mondayOfWeek);

    return _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.weekStartDate, weekStartDate)
        .eq(DatabaseConstants.isPublished, true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (data.isEmpty) return null;
      return WeeklyMenu.fromMap((data as List).first);
    });
  }

  /// Get weekly menu by week start date
  @override
  Future<WeeklyMenu?> getWeeklyMenuByDate(DateTime date) async {
    final mondayOfWeek = _getMondayOfWeek(date);
    final weekStartDate = _formatDate(mondayOfWeek);

    final snapshot = await _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.weekStartDate, weekStartDate)
        .limit(1)
        .get();

    if (data.isEmpty) return null;
    return WeeklyMenu.fromMap((data as List).first);
  }

  /// Get all published weekly menus (paginated)
  @override
  Stream<List<WeeklyMenu>> getPublishedWeeklyMenus({int limit = DatabaseConstants.defaultPageSize}) {
    return _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.isPublished, true)
        .order(DatabaseConstants.weekStartDate, ascending: false)
        .limit(limit)
        .snapshots()
        .map((data) =>
            data.map((item) => WeeklyMenu.fromMap(item)).toList());
  }

  /// Publish a new weekly menu (V2 with nested meal types)
  @override
  Future<void> publishWeeklyMenu({
    required DateTime weekStartDate,
    required Map<String, Map<String, List<String>>> menuByDay,
    String? publishedBy,
    String? copiedFromWeek,
  }) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    final weekStartDateStr = _formatDate(mondayOfWeek);

    // Check if a menu already exists for this week
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    
    if (existing != null) {
      // Update existing menu
      final updated = existing.copyWith(
        menuByDay: menuByDay,
        copiedFromWeek: copiedFromWeek,
        isPublished: true,
        publishedAt: DateTime.now(),
        publishedBy: publishedBy,
        updatedAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .doc(existing.id)
          .update(updated.toMap());
    } else {
      // Create new menu
      final weeklyMenu = WeeklyMenu(
        id: _uuid.v4(),
        weekStartDate: weekStartDateStr,
        copiedFromWeek: copiedFromWeek,
        menuByDay: menuByDay,
        isPublished: true,
        publishedAt: DateTime.now(),
        publishedBy: publishedBy,
        createdAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .doc(weeklyMenu.id)
          .set(weeklyMenu.toMap());
    }
  }

  /// Unpublish a weekly menu
  @override
  Future<void> unpublishWeeklyMenu(String menuId) async {
    await _supabase.from('weekly_menus').update({
      DatabaseConstants.isPublished: false,
      DatabaseConstants.updatedAt: DateTime.now().toIso8601String().eq('id', menuId),
    });
  }

  /// Delete a weekly menu
  @override
  Future<void> deleteWeeklyMenu(String menuId) async {
    await _supabase.from('weekly_menus').delete().eq('id', menuId);
  }

  /// Update weekly menu data (without publishing)
  @override
  Future<void> updateWeeklyMenu(
    String weekStartDate,
    Map<String, Map<String, List<String>>> menuByDay,
  ) async {
    final mondayOfWeek = _getMondayOfWeek(DateTime.parse(weekStartDate));
    final weekStartDateStr = _formatDate(mondayOfWeek);
    
    // Check if menu exists
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    
    if (existing != null) {
      // Update existing menu
      await _supabase.from('weekly_menus').update({
        DatabaseConstants.menuByDay: _convertMenuByDayToMap(menuByDay).eq('id', existing.id),
        DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
      });
    } else {
      // Create new unpublished menu (publishedAt is null for unpublished)
      final weeklyMenu = WeeklyMenu(
        id: _uuid.v4(),
        weekStartDate: weekStartDateStr,
        menuByDay: menuByDay,
        isPublished: false,
        publishedAt: null, // Null until published
        createdAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .doc(weeklyMenu.id)
          .set(weeklyMenu.toMap());
    }
  }
  
  /// Convert menuByDay to Firestore-compatible Map
  Map<String, dynamic> _convertMenuByDayToMap(Map<String, Map<String, List<String>>> menuByDay) {
    return menuByDay.map((day, mealTypes) {
      return MapEntry(day, mealTypes.map((mealType, items) {
        return MapEntry(mealType, items);
      }));
    });
  }

  /// Get menu items for a specific day and meal type from weekly menu (V2)
  @override
  Future<List<MenuItem>> getMenuItemsForDay(
    WeeklyMenu weeklyMenu,
    String day, {
    String? mealType,
  }) async {
    final dayMenu = weeklyMenu.menuByDay[day];
    if (dayMenu == null || dayMenu.isEmpty) return [];

    // Get all item IDs for the day (all meal types if not specified)
    final List<String> itemIds = [];
    if (mealType != null) {
      itemIds.addAll(dayMenu[mealType] ?? []);
    } else {
      for (var mealTypeItems in dayMenu.values) {
        itemIds.addAll(mealTypeItems);
      }
    }

    if (itemIds.isEmpty) return [];

    // Fetch menu items in batches (Firestore 'in' query limit)
    final List<MenuItem> items = [];
    for (int i = 0; i < itemIds.length; i += DatabaseConstants.inQueryLimit) {
      final batch = itemIds.skip(i).take(DatabaseConstants.inQueryLimit).toList();
      final snapshot = await _supabase
          .from('menu_items')
          .where('id', in_: batch)
          .get();
      items.addAll(
          data.map((item) => MenuItem.fromMap(item)).toList());
    }
    return items;
  }

  /// Update menu items' availableDays field when publishing
  @override
  Future<void> updateMenuItemsAvailability(
    Map<String, Map<String, List<String>>> menuByDay,
  ) async {
    // Create a map of itemId -> list of days it appears
    final Map<String, List<String>> itemDaysMap = {};
    
    for (final entry in menuByDay.entries) {
      final day = entry.key;
      final mealTypes = entry.value;
      
      for (final mealTypeEntry in mealTypes.entries) {
        final itemIds = mealTypeEntry.value;
        
        for (final itemId in itemIds) {
          if (!itemDaysMap.containsKey(itemId)) {
            itemDaysMap[itemId] = [];
          }
          if (!itemDaysMap[itemId]!.contains(day)) {
            itemDaysMap[itemId]!.add(day);
          }
        }
      }
    }

    // Update each menu item's availableDays field
    final batch = _supabase.batch();
    int batchCount = 0;

    for (final entry in itemDaysMap.entries) {
      final itemId = entry.key;
      final days = entry.value;
      
      final docRef = _supabase.from('menu_items').doc(itemId);
      batch.update(docRef, {
        DatabaseConstants.availableDays: days,
        DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
      });
      
      batchCount++;
      
      // Commit batch if reaching limit (500 operations)
      if (batchCount >= 500) {
        // Use .insert([...]) for bulk operations
        batchCount = 0;
      }
    }

    // Commit remaining operations
    if (batchCount > 0) {
      // Use .insert([...]) for bulk operations
    }
  }

  /// Copy menu from previous week to a new week (V2)
  /// Creates an UNPUBLISHED copy that must be manually published
  @override
  Future<void> copyMenuFromPreviousWeek(DateTime targetWeekStart) async {
    final targetMonday = _getMondayOfWeek(targetWeekStart);
    final previousMonday = targetMonday.subtract(const Duration(days: 7));
    
    // Get previous week's menu
    final previousMenu = await getWeeklyMenuByDate(previousMonday);
    if (previousMenu == null) {
      throw Exception('No menu found for previous week');
    }

    // Check if menu already exists for target week
    final existing = await getWeeklyMenuByDate(targetMonday);
    final targetWeekStartStr = _formatDate(targetMonday);
    
    if (existing != null) {
      // Update existing menu (keep current published state)
      await _supabase.from('weekly_menus').update({
        DatabaseConstants.menuByDay: _convertMenuByDayToMap(previousMenu.menuByDay).eq('id', existing.id),
        DatabaseConstants.copiedFromWeek: previousMenu.weekStartDate,
        DatabaseConstants.updatedAt: DateTime.now().toIso8601String(),
      });
    } else {
      // Create new UNPUBLISHED menu copy
      final weeklyMenu = WeeklyMenu(
        id: _uuid.v4(),
        weekStartDate: targetWeekStartStr,
        copiedFromWeek: previousMenu.weekStartDate,
        menuByDay: previousMenu.menuByDay,
        isPublished: false, // NOT auto-published
        publishedAt: null, // Null until manually published
        createdAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .doc(weeklyMenu.id)
          .set(weeklyMenu.toMap());
    }
  }

  /// Get weekly menu history (past published menus)
  @override
  Future<List<WeeklyMenu>> getWeeklyMenuHistory({int limit = 10}) async {
    final snapshot = await _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.isPublished, true)
        .order(DatabaseConstants.weekStartDate, ascending: false)
        .limit(limit)
        .get();

    return data
        .map((doc) => WeeklyMenu.fromMap(item))
        .toList();
  }

  /// Stream weekly menu history
  @override
  Stream<List<WeeklyMenu>> streamWeeklyMenuHistory({int limit = DatabaseConstants.defaultPageSize}) {
    return _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.isPublished, true)
        .order(DatabaseConstants.weekStartDate, ascending: false)
        .limit(limit)
        .snapshots()
        .map((data) =>
            data.map((item) => WeeklyMenu.fromMap(item)).toList());
  }

  /// Get menu for a specific week by week start date string
  @override
  Future<WeeklyMenu?> getMenuForWeek(String weekStartDate) async {
    final snapshot = await _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.weekStartDate, weekStartDate)
        .limit(1)
        .get();

    if (data.isEmpty) return null;
    return WeeklyMenu.fromMap((data as List).first);
  }

  /// Stream menu for a specific week
  @override
  Stream<WeeklyMenu?> streamMenuForWeek(String weekStartDate) {
    return _supabase
        .from('weekly_menus')
        .eq(DatabaseConstants.weekStartDate, weekStartDate)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (data.isEmpty) return null;
      return WeeklyMenu.fromMap((data as List).first);
    });
  }

  /// Validate menu structure and item limits (V2)
  @override
  Map<String, dynamic> validateMenu(Map<String, Map<String, List<String>>> menuByDay) {
    final errors = <String>[];
    final warnings = <String>[];
    
    for (var dayEntry in menuByDay.entries) {
      final day = dayEntry.key;
      final mealTypes = dayEntry.value;
      
      for (var mealTypeEntry in mealTypes.entries) {
        final mealType = mealTypeEntry.key;
        final items = mealTypeEntry.value;
        final maxItems = MealType.maxItems[mealType] ?? 10;
        final displayName = MealType.displayNames[mealType] ?? mealType; // Fallback to key if not found
        
        if (items.length > maxItems) {
          errors.add('$day - $displayName: '
              'Exceeds maximum of $maxItems items (has ${items.length})');
        }
        
        if (items.isEmpty) {
          warnings.add('$day - $displayName: No items selected');
        }
      }
    }
    
    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
    };
  }

  /// Helper: Get Monday of the week for a given date
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Helper: Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get week date range as string (e.g., "Jan 6 - Jan 10, 2025")
  @override
  String getWeekDateRange(DateTime monday) {
    final friday = monday.add(const Duration(days: 4));
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (monday.month == friday.month) {
      return '${months[monday.month]} ${monday.day} - ${friday.day}, ${monday.year}';
    } else {
      return '${months[monday.month]} ${monday.day} - ${months[friday.month]} ${friday.day}, ${monday.year}';
    }
  }
}
