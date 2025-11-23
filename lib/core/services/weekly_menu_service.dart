import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/weekly_menu.dart';
import '../models/menu_item.dart';
import '../interfaces/i_weekly_menu_service.dart';

/// Weekly Menu Service - handles all WeeklyMenu-related Supabase operations
class WeeklyMenuService implements IWeeklyMenuService {
  final SupabaseClient _supabase;
  final Uuid _uuid;

  /// Constructor with dependency injection
  WeeklyMenuService({
    SupabaseClient? supabase,
    Uuid? uuid,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _uuid = uuid ?? const Uuid();

  /// Get the current week's menu
  @override
  Stream<WeeklyMenu?> getCurrentWeeklyMenu() {
    final today = DateTime.now();
    final mondayOfWeek = _getMondayOfWeek(today);
    final weekStart = _formatDate(mondayOfWeek);

    return _supabase
        .from('weekly_menus')
        .stream(primaryKey: ['id'])
        .eq('week_start', weekStart)
        .map((data) {
      if (data.isEmpty) return null;
      return WeeklyMenu.fromMap(data.first);
    });
  }

  /// Get weekly menu by week start date
  @override
  Future<WeeklyMenu?> getWeeklyMenuByDate(DateTime date) async {
    final mondayOfWeek = _getMondayOfWeek(date);
    final weekStart = _formatDate(mondayOfWeek);

    final data = await _supabase
        .from('weekly_menus')
        .select()
        .eq('week_start', weekStart)
        .limit(1);

    if ((data as List).isEmpty) return null;
    return WeeklyMenu.fromMap((data as List).first);
  }

  /// Get all published weekly menus as a stream (filters by publish_status)
  @override
  Stream<List<WeeklyMenu>> getPublishedWeeklyMenus({int limit = 50}) {
    return _supabase
        .from('weekly_menus')
        .stream(primaryKey: ['id'])
        .eq('publish_status', PublishStatus.published)
        .order('week_start', ascending: false)
        .limit(limit)
        .map((data) =>
            data.map((item) => WeeklyMenu.fromMap(item)).toList());
  }

  /// Publish a weekly menu: upsert, set status, version, and snapshot
  @override
  Future<void> publishWeeklyMenu({
    required DateTime weekStartDate,
    required Map<String, Map<String, List<String>>> menuByDay,
  }) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    // Normalize input to match DB expectations (Mon-Fri only, lowercase meal keys)
    final normalizedMenu = _normalizeMenuByDay(menuByDay);

    // Check if a menu already exists for this week
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    
    if (existing != null) {
      // Increment version and mark as published
      final newVersion = (existing.currentVersion) + 1;
      await _supabase
          .from('weekly_menus')
          .update({
            'menu_items_by_day': normalizedMenu,
            'publish_status': PublishStatus.published,
            'current_version': newVersion,
            'published_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing.id);

      // Snapshot into versions table
      await _supabase.from('weekly_menu_versions').insert({
        'weekly_menu_id': existing.id,
        'version': newVersion,
        'week_start': _formatDate(mondayOfWeek),
        'menu_items_by_day': normalizedMenu,
        'created_by': _supabase.auth.currentUser?.id,
      });
    } else {
      // Create new menu and mark as published (version = 1)
      final weeklyMenu = WeeklyMenu(
        id: _uuid.v4(),
        weekStart: mondayOfWeek,
        menuItemsByDay: normalizedMenu,
        createdAt: DateTime.now(),
        publishStatus: PublishStatus.published,
        currentVersion: 1,
        publishedAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .insert(weeklyMenu.toMap());

      // Snapshot initial version
      await _supabase.from('weekly_menu_versions').insert({
        'weekly_menu_id': weeklyMenu.id,
        'version': 1,
        'week_start': _formatDate(mondayOfWeek),
        'menu_items_by_day': normalizedMenu,
        'created_by': _supabase.auth.currentUser?.id,
      });
    }
  }

  /// Delete a weekly menu
  @override
  Future<void> deleteWeeklyMenu(String menuId) async {
    await _supabase.from('weekly_menus').delete().eq('id', menuId);
  }

  /// Update weekly menu data (keeps menu in draft until published)
  @override
  Future<void> updateWeeklyMenu(
    String weekStartDate,
    Map<String, Map<String, List<String>>> menuByDay,
  ) async {
    final mondayOfWeek = _getMondayOfWeek(DateTime.parse(weekStartDate));
    // Normalize input to match DB expectations (Mon-Fri only, lowercase meal keys)
    final normalizedMenu = _normalizeMenuByDay(menuByDay);
    
    // Check if menu exists
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    
    if (existing != null) {
      // Update existing menu
      await _supabase.from('weekly_menus').update({
        'menu_items_by_day': normalizedMenu,
        'publish_status': PublishStatus.draft, // editing returns to draft until explicitly published
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing.id);
    } else {
      // Insert new weekly menu if it doesn't exist (upsert behavior)
      await _supabase.from('weekly_menus').insert({
        'id': _uuid.v4(),
        'week_start': _formatDate(mondayOfWeek),
        'menu_items_by_day': normalizedMenu,
        'publish_status': PublishStatus.draft,
        'current_version': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Unpublish a weekly menu by setting status to draft and clearing published_at
  @override
  Future<void> unpublishWeeklyMenu(DateTime weekStartDate) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    if (existing == null) return;
    await _supabase.from('weekly_menus').update({
      'publish_status': PublishStatus.draft,
      'published_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', existing.id);
  }

  /// Get versions for a week (latest first)
  @override
  Future<List<Map<String, dynamic>>> getWeeklyMenuVersions(DateTime weekStartDate) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    if (existing == null) return [];
    final data = await _supabase
        .from('weekly_menu_versions')
        .select()
        .eq('weekly_menu_id', existing.id)
        .order('version', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Revert content to a given version (status becomes draft until re-publish)
  @override
  Future<void> revertToVersion(DateTime weekStartDate, int version) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    if (existing == null) throw Exception('No weekly menu found for week');
    final data = await _supabase
        .from('weekly_menu_versions')
        .select()
        .eq('weekly_menu_id', existing.id)
        .eq('version', version)
        .limit(1);
    if ((data as List).isEmpty) throw Exception('Version not found');
    final versionRow = (data as List).first as Map<String, dynamic>;
    final snapshot = Map<String, Map<String, List<String>>>.from(
      (versionRow['menu_items_by_day'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Map<String, List<String>>.from(
          (v as Map<String, dynamic>).map((kk, vv) => MapEntry(kk, List<String>.from(vv as List)))))
      )
    );
    await _supabase.from('weekly_menus').update({
      'menu_items_by_day': snapshot,
      'publish_status': PublishStatus.draft,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', existing.id);
  }

  /// Archive a weekly menu
  @override
  Future<void> archiveWeeklyMenu(DateTime weekStartDate) async {
    final mondayOfWeek = _getMondayOfWeek(weekStartDate);
    final existing = await getWeeklyMenuByDate(mondayOfWeek);
    if (existing == null) return;
    await _supabase.from('weekly_menus').update({
      'publish_status': PublishStatus.archived,
      'archived_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', existing.id);
  }

  // Normalize menu structure: keep only Monday–Friday, enforce lowercase meal keys
  Map<String, Map<String, List<String>>> _normalizeMenuByDay(
    Map<String, Map<String, List<String>>> input,
  ) {
    const allowedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final result = <String, Map<String, List<String>>>{};
    for (final day in allowedDays) {
      final dayMenu = input[day] ?? const <String, List<String>>{};
      result[day] = {
        'breakfast': List<String>.from(dayMenu['breakfast'] ?? const <String>[]),
        'lunch': List<String>.from(dayMenu['lunch'] ?? const <String>[]),
        'snack': List<String>.from(dayMenu['snack'] ?? const <String>[]),
        'drinks': List<String>.from(dayMenu['drinks'] ?? const <String>[]),
      };
    }
    return result;
  }

  /// Get menu items for a specific day and meal type from weekly menu
  @override
  Future<List<MenuItem>> getMenuItemsForDay(
    WeeklyMenu weeklyMenu,
    String day, {
    String? mealType,
  }) async {
    final dayMenu = weeklyMenu.menuItemsByDay[day];
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

    // Fetch menu items in batches (Supabase 'in' query limit)
    final List<MenuItem> items = [];
    const inQueryLimit = 100; // Supabase limit for 'in' queries
    for (int i = 0; i < itemIds.length; i += inQueryLimit) {
      final batch = itemIds.skip(i).take(inQueryLimit).toList();
      final data = await _supabase
          .from('menu_items')
          .select()
          .inFilter('id', batch);
      items.addAll(
          (data as List).map((item) => MenuItem.fromMap(item)).toList());
    }
    
    // Filter out unavailable items (Fix Issue #4)
    return items.where((item) => item.isAvailable).toList();
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
    // Note: Supabase doesn't have batch operations like Firebase Firestore
    // We'll use bulk update approach instead
    final List<Map<String, dynamic>> updates = [];

    for (final entry in itemDaysMap.entries) {
      final itemId = entry.key;
      final days = entry.value;
      
      updates.add({
        'id': itemId,
        'available_days': days,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Update in batches of 100 to avoid API limits
      if (updates.length >= 100) {
        await _supabase.from('menu_items').upsert(updates);
        updates.clear();
      }
    }

    // Update remaining items
    if (updates.isNotEmpty) {
      await _supabase.from('menu_items').upsert(updates);
    }
  }

  /// Copy menu from previous week to a new week
  /// Creates a new menu or updates existing menu (immediately available - no publishing concept)
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
    
    if (existing != null) {
      // Update existing menu
      await _supabase.from('weekly_menus').update({
        'menu_items_by_day': previousMenu.menuItemsByDay,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing.id);
    } else {
      // Create new menu copy
      final weeklyMenu = WeeklyMenu(
        id: _uuid.v4(),
        weekStart: targetMonday,
        menuItemsByDay: previousMenu.menuItemsByDay,
        createdAt: DateTime.now(),
      );
      await _supabase
          .from('weekly_menus')
          .insert(weeklyMenu.toMap());
    }
  }

  /// Get weekly menu history (all menus regardless of status)
  @override
  Future<List<WeeklyMenu>> getWeeklyMenuHistory({int limit = 10}) async {
    final data = await _supabase
        .from('weekly_menus')
        .select()
        .order('week_start', ascending: false)
        .limit(limit);

    return (data as List)
        .map((item) => WeeklyMenu.fromMap(item))
        .toList();
  }

  /// Stream weekly menu history (all menus - no publishing filter)
  @override
  Stream<List<WeeklyMenu>> streamWeeklyMenuHistory({int limit = 50}) {
    return _supabase
        .from('weekly_menus')
        .stream(primaryKey: ['id'])
        .order('week_start', ascending: false)
        .limit(limit)
        .map((data) =>
            data.map((item) => WeeklyMenu.fromMap(item)).toList());
  }

  /// Get menu for a specific week by week start date string
  @override
  Future<WeeklyMenu?> getMenuForWeek(String weekStartDate) async {
    final data = await _supabase
        .from('weekly_menus')
        .select()
        .eq('week_start', weekStartDate)
        .limit(1);

    if ((data as List).isEmpty) return null;
    return WeeklyMenu.fromMap((data as List).first);
  }

  /// Stream menu for a specific week
  @override
  Stream<WeeklyMenu?> streamMenuForWeek(String weekStartDate) {
    return _supabase
        .from('weekly_menus')
        .stream(primaryKey: ['id'])
        .eq('week_start', weekStartDate)
        .limit(1)
        .map((data) {
      if (data.isEmpty) return null;
      return WeeklyMenu.fromMap(data.first);
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
  
  /// Validate menu items availability (Fix Issue #4)
  /// Returns a map of unavailable item IDs found in the menu
  Future<Map<String, dynamic>> validateMenuItemsAvailability(
    Map<String, Map<String, List<String>>> menuByDay
  ) async {
    final warnings = <String>[];
    final unavailableItemIds = <String>[];
    
    // Collect all unique item IDs
    final allItemIds = <String>{};
    for (var dayEntry in menuByDay.entries) {
      for (var mealTypeEntry in dayEntry.value.entries) {
        allItemIds.addAll(mealTypeEntry.value);
      }
    }
    
    if (allItemIds.isEmpty) {
      return {
        'isValid': true,
        'warnings': warnings,
        'unavailableItemIds': unavailableItemIds,
      };
    }
    
    // Fetch items and check availability
    final items = <MenuItem>[];
    const inQueryLimit = 100;
    final itemIdsList = allItemIds.toList();
    
    for (int i = 0; i < itemIdsList.length; i += inQueryLimit) {
      final batch = itemIdsList.skip(i).take(inQueryLimit).toList();
      final data = await _supabase
          .from('menu_items')
          .select()
          .inFilter('id', batch);
      items.addAll(
          (data as List).map((item) => MenuItem.fromMap(item)).toList());
    }
    
    // Build a map of item ID to availability
    final itemAvailability = <String, bool>{};
    final itemNames = <String, String>{};
    for (var item in items) {
      itemAvailability[item.id] = item.isAvailable;
      itemNames[item.id] = item.name;
    }
    
    // Check each item in the menu
    for (var dayEntry in menuByDay.entries) {
      final day = dayEntry.key;
      for (var mealTypeEntry in dayEntry.value.entries) {
        final mealType = mealTypeEntry.key;
        final displayName = MealType.displayNames[mealType] ?? mealType;
        
        for (var itemId in mealTypeEntry.value) {
          final isAvailable = itemAvailability[itemId];
          if (isAvailable == false) {
            final itemName = itemNames[itemId] ?? 'Unknown Item';
            warnings.add('$day - $displayName: "$itemName" is unavailable');
            unavailableItemIds.add(itemId);
          } else if (isAvailable == null) {
            warnings.add('$day - $displayName: Item ID $itemId not found in database');
            unavailableItemIds.add(itemId);
          }
        }
      }
    }
    
    return {
      'isValid': unavailableItemIds.isEmpty,
      'warnings': warnings,
      'unavailableItemIds': unavailableItemIds,
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
