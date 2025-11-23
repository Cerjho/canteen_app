import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import '../interfaces/i_menu_service.dart';

/// MenuService - Master Inventory Management Service
/// 
/// Purpose: Handles CRUD operations for food/drink items in the catalog (Tab 1: All Menu Items)
/// - Create, Read, Update, Delete menu items
/// - Manage item properties (availability, stock, images, etc.)
/// - Import/Export functionality
/// - Search and filtering
/// 
/// NOT for scheduling - use WeeklyMenuService for assigning items to days/weeks (Tab 2)
/// 
/// Separation of concerns:
/// - MenuService = Inventory management (what items exist)
/// - WeeklyMenuService = Schedule management (when items are served)
class MenuService implements IMenuService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  MenuService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Get all menu items
  @override
  Stream<List<MenuItem>> getMenuItems() {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) =>
            data.map((item) => MenuItem.fromMap(item)).toList());
  }

  /// Get available menu items only
  @override
  Stream<List<MenuItem>> getAvailableMenuItems() {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('is_available', true)
        .order('created_at', ascending: false)
        .map((data) =>
            data.map((item) => MenuItem.fromMap(item)).toList());
  }

  /// Get menu items by category
  @override
  Stream<List<MenuItem>> getMenuItemsByCategory(String category) {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('category', category)
        .order('name')
        .map((data) =>
            data.map((item) => MenuItem.fromMap(item)).toList());
  }

  /// Get menu item by ID
  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    final data = await _supabase.from('menu_items').select().eq('id', id).maybeSingle();
    if (data != null) {
      return MenuItem.fromMap(data);
    }
    return null;
  }

  /// Get menu item stream by ID
  @override
  Stream<MenuItem?> getMenuItemStream(String id) {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) =>
            data.isNotEmpty ? MenuItem.fromMap(data.first) : null);
  }

  /// Create a new menu item (Alias for createMenuItem)
  @override
  Future<void> addMenuItem(MenuItem menuItem) async {
    // Check for duplicate by name (case-insensitive)
    final existingItem = await _checkDuplicateByName(menuItem.name);
    if (existingItem != null) {
      throw Exception('A menu item with the name "${menuItem.name}" already exists.');
    }
    
    await _supabase
        .from('menu_items')
        .insert(menuItem.toMap());
  }

  /// Create a new menu item
  Future<void> createMenuItem(MenuItem menuItem) async {
    await addMenuItem(menuItem);
  }

  /// Check if a menu item with the same name exists
  Future<MenuItem?> _checkDuplicateByName(String name) async {
    final data = await _supabase
        .from('menu_items')
        .select()
        .eq('name', name)
        .limit(1);
    
    if ((data as List).isNotEmpty) {
      return MenuItem.fromMap((data as List).first);
    }
    return null;
  }

  /// Update menu item
  @override
  Future<void> updateMenuItem(MenuItem menuItem) async {
    final updatedMenuItem = menuItem.copyWith(updatedAt: DateTime.now());
    await _supabase
        .from('menu_items')
        .update(updatedMenuItem.toMap())
        .eq('id', menuItem.id);
  }

  /// Delete menu item
  @override
  Future<void> deleteMenuItem(String id) async {
    // First, remove this item ID from all weekly menus
    await _removeMenuItemFromWeeklyMenus(id);
    
    // Then delete the menu item itself
    await _supabase.from('menu_items').delete().eq('id', id);
  }
  
  /// Remove a menu item ID from all weekly menus (orphan cleanup)
  /// This prevents "Unknown Item" entries when switching to Weekly Menu tab
  Future<void> _removeMenuItemFromWeeklyMenus(String itemId) async {
    try {
      // Fetch all weekly menus
      final weeklyMenusData = await _supabase
          .from('weekly_menus')
          .select('id, menu_items_by_day');
      
      final weeklyMenus = weeklyMenusData as List;
      
      for (var menuData in weeklyMenus) {
        final menuId = menuData['id'] as String;
        final menuItemsByDay = Map<String, dynamic>.from(
          menuData['menu_items_by_day'] as Map<String, dynamic>? ?? {}
        );
        
        bool modified = false;
        
        // Iterate through each day and meal type
        for (var dayEntry in menuItemsByDay.entries.toList()) {
          final day = dayEntry.key;
          final mealTypesData = Map<String, dynamic>.from(
            dayEntry.value as Map<String, dynamic>? ?? {}
          );
          
          for (var mealTypeEntry in mealTypesData.entries.toList()) {
            final mealType = mealTypeEntry.key;
            final itemIds = List<String>.from(
              mealTypeEntry.value as List? ?? []
            );
            
            // Remove the deleted item ID if present
            if (itemIds.contains(itemId)) {
              itemIds.remove(itemId);
              mealTypesData[mealType] = itemIds;
              modified = true;
            }
          }
          
          menuItemsByDay[day] = mealTypesData;
        }
        
        // Update the weekly menu if modified
        if (modified) {
          await _supabase.from('weekly_menus').update({
            'menu_items_by_day': menuItemsByDay,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', menuId);
        }
      }
    } catch (e) {
      // Log error but don't throw - deleting the menu item is more important
      // than cleaning up orphan references
      print('Warning: Failed to clean up orphan menu item references: $e');
    }
  }

  /// Toggle menu item availability (interface implementation)
  @override
  Future<void> toggleAvailability(String menuItemId, bool isAvailable) async {
    await updateAvailability(menuItemId, isAvailable);
  }

  /// Toggle menu item availability (legacy method - auto-toggles)
  Future<void> toggleAvailabilityAuto(String menuItemId) async {
    final data = await _supabase.from('menu_items').select().eq('id', menuItemId).maybeSingle();
    if (data != null) {
      final currentAvailability = data['is_available'] as bool? ?? true;
      await updateAvailability(menuItemId, !currentAvailability);
    }
  }

  /// Update menu item availability
  Future<void> updateAvailability(String menuItemId, bool isAvailable) async {
    await _supabase.from('menu_items').update({
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', menuItemId);
  }

  /// Update stock quantity - DEPRECATED: stock_quantity field removed from schema
  @override
  Future<void> updateStockQuantity(String id, int quantity) async {
    // No-op: stock_quantity field does not exist in database schema
    // This method is kept for interface compatibility only
    throw UnsupportedError('stock_quantity field has been removed from the database schema');
  }

  /// Update stock (legacy method - alias) - DEPRECATED
  Future<void> updateStock(String menuItemId, int quantity) async {
    // No-op: stock_quantity field does not exist in database schema
    throw UnsupportedError('stock_quantity field has been removed from the database schema');
  }

  /// Delete menu item image from storage and update Supabase
  Future<void> deleteMenuItemImage(String menuItemId) async {
    await _supabase.from('menu_items').update({
      'image_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', menuItemId);
  }
  /// Update menu item image URL
  Future<void> updateMenuItemImage(String menuItemId, String imageUrl) async {
    await _supabase.from('menu_items').update({
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', menuItemId);
  }

  /// Get menu items by available days
  /// Note: This returns all menu items. Day availability is managed via WeeklyMenuService.
  @override
  Stream<List<MenuItem>> getMenuItemsByAvailableDays(List<String> days) {
    // MenuItem model doesn't have availableDays field - it's managed at weekly menu level
    // Return all available items - filtering by days should be done at WeeklyMenuService level
    return getAvailableMenuItems();
  }

  /// Search menu items by name
  @override
  Stream<List<MenuItem>> searchMenuItems(String query) {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((data) => data
            .map((item) => MenuItem.fromMap(item))
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  /// Get menu categories
  Future<List<String>> getCategories() async {
    final data = await _supabase.from('menu_items').select();
    final categories = (data as List)
        .map((item) => item['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  /// Get menu items count
  Future<int> getMenuItemsCount() async {
    final data = await _supabase.from('menu_items').select('id');
    return (data as List).length;
  }

  /// Get available menu items count
  Future<int> getAvailableMenuItemsCount() async {
    final data = await _supabase
        .from('menu_items')
        .select('id')
        .eq('is_available', true);
    return (data as List).length;
  }

  /// Import menu items from CSV/Excel file
  /// Returns a map with success count, failed items, and duplicates
  Future<Map<String, dynamic>> importMenuItemsFromFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    if (fileName.toLowerCase().endsWith('.csv')) {
      return await _importFromCsv(fileBytes);
    } else if (fileName.toLowerCase().endsWith('.xlsx') ||
        fileName.toLowerCase().endsWith('.xls')) {
      return await _importFromExcel(fileBytes);
    } else {
      throw Exception('Unsupported file format. Use CSV or Excel files.');
    }
  }

  /// Parse CSV file and import menu items
  Future<Map<String, dynamic>> _importFromCsv(Uint8List fileBytes) async {
    final csvString = utf8.decode(fileBytes);
    final csvData = const CsvToListConverter().convert(csvString);

    if (csvData.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Parse header
    final headers =
        csvData[0].map((e) => e.toString().toLowerCase().trim()).toList();
    final rows = csvData.sublist(1);

    return await _batchImportMenuItems(headers, rows);
  }

  /// Parse Excel file and import menu items
  Future<Map<String, dynamic>> _importFromExcel(Uint8List fileBytes) async {
    final excel = Excel.decodeBytes(fileBytes);
    final sheet = excel.tables.values.first;

    if (sheet.rows.isEmpty) {
      throw Exception('Excel file is empty');
    }

    // Parse header
    final headers = sheet.rows[0]
        .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
        .toList();
    final rows = sheet.rows.sublist(1).map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();

    return await _batchImportMenuItems(headers, rows);
  }

  /// Batch import menu items with validation
  Future<Map<String, dynamic>> _batchImportMenuItems(
    List<dynamic> headers,
    List<List<dynamic>> rows,
  ) async {
    final uuid = const Uuid();
    int successCount = 0;
    int duplicateCount = 0;
    final List<Map<String, dynamic>> failedItems = [];

    // Get column indices
    final nameIdx = headers.indexOf('name');
    final descriptionIdx = headers.indexOf('description');
    final priceIdx = headers.indexOf('price');
    final categoryIdx = headers.indexOf('category');
    final allergensIdx = headers.indexOf('allergens');
    final dietaryLabelsIdx = headers.indexOf('dietarylabels');
    final prepTimeIdx = headers.indexOf('preptimeminutes');
    final isAvailableIdx = headers.indexOf('isavailable');
    // Legacy boolean columns for backward compatibility
    final isVegetarianIdx = headers.indexOf('isvegetarian');
    final isVeganIdx = headers.indexOf('isvegan');
    final isGlutenFreeIdx = headers.indexOf('isglutenfree');

    if (nameIdx == -1 || descriptionIdx == -1 || priceIdx == -1 || categoryIdx == -1) {
      throw Exception(
          'CSV must contain required columns: name, description, price, category');
    }

    // Fetch existing menu items to check duplicates
    final existingData = await _supabase.from('menu_items').select();
    final existingNames =
        (existingData as List).map((item) => item['name'] as String).toSet();

    // Collect items to bulk insert
    final List<Map<String, dynamic>> itemsToInsert = [];

    for (int i = 0; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.isEmpty || (nameIdx < row.length && row[nameIdx].toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }

        final name = row[nameIdx].toString().trim();
        final description = descriptionIdx < row.length ? row[descriptionIdx].toString().trim() : '';
        final priceStr = priceIdx < row.length ? row[priceIdx].toString().trim() : '0';
        final category = categoryIdx < row.length ? row[categoryIdx].toString().trim() : '';

        // Validation
        if (name.isEmpty || description.isEmpty || category.isEmpty) {
          failedItems.add({
            'row': i + 2,
            'error': 'Missing required fields (name, description, or category)',
          });
          continue;
        }

        // Check for duplicates
        if (existingNames.contains(name)) {
          duplicateCount++;
          continue;
        }

        // Parse price
        final price = double.tryParse(priceStr);
        if (price == null || price < 0) {
          failedItems.add({
            'row': i + 2,
            'error': 'Invalid price: $priceStr',
          });
          continue;
        }

        // Parse optional fields
        final allergensStr = allergensIdx != -1 && allergensIdx < row.length
            ? row[allergensIdx].toString().trim()
            : '';
        final allergens = allergensStr.isNotEmpty
            ? allergensStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];

        // Parse dietary labels - prioritize new column format, fallback to legacy booleans
        List<String> dietaryLabels = [];
        if (dietaryLabelsIdx != -1 && dietaryLabelsIdx < row.length) {
          // New format: comma-separated dietary labels
          final dietaryLabelsStr = row[dietaryLabelsIdx].toString().trim();
          if (dietaryLabelsStr.isNotEmpty) {
            dietaryLabels = dietaryLabelsStr
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } else {
          // Legacy format: build from boolean columns
          final isVegetarian = isVegetarianIdx != -1 && isVegetarianIdx < row.length
              ? _parseBool(row[isVegetarianIdx].toString())
              : false;
          final isVegan = isVeganIdx != -1 && isVeganIdx < row.length
              ? _parseBool(row[isVeganIdx].toString())
              : false;
          final isGlutenFree = isGlutenFreeIdx != -1 && isGlutenFreeIdx < row.length
              ? _parseBool(row[isGlutenFreeIdx].toString())
              : false;
          
          if (isVegetarian) dietaryLabels.add('Vegetarian');
          if (isVegan) dietaryLabels.add('Vegan');
          if (isGlutenFree) dietaryLabels.add('Gluten-Free');
        }

        // Parse prep time
        final prepTimeStr = prepTimeIdx != -1 && prepTimeIdx < row.length
            ? row[prepTimeIdx].toString().trim()
            : '';
        final prepTimeMinutes = prepTimeStr.isNotEmpty ? int.tryParse(prepTimeStr) : null;

        // Parse isAvailable - support TRUE/FALSE, Yes/No, 1/0, or default to true
        bool isAvailable = true;
        if (isAvailableIdx != -1 && isAvailableIdx < row.length) {
          isAvailable = _parseBool(row[isAvailableIdx].toString());
        }

        // Create menu item
        final menuItem = MenuItem(
          id: uuid.v4(),
          name: name,
          description: description,
          price: price,
          category: category,
          allergens: allergens,
          dietaryLabels: dietaryLabels,
          prepTimeMinutes: prepTimeMinutes,
          isAvailable: isAvailable,
          createdAt: DateTime.now(),
        );

        // Add to bulk insert list
        itemsToInsert.add(menuItem.toMap());
        successCount++;
        existingNames.add(name); // Prevent duplicates within same import

        // Insert in batches of 500 to avoid API limits
        if (itemsToInsert.length >= 500) {
          await _supabase.from('menu_items').insert(itemsToInsert);
          itemsToInsert.clear();
        }
      } catch (e) {
        failedItems.add({
          'row': i + 2,
          'error': e.toString(),
        });
      }
    }

    // Insert remaining items
    if (itemsToInsert.isNotEmpty) {
      await _supabase.from('menu_items').insert(itemsToInsert);
    }

    return {
      'success': successCount,
      'duplicates': duplicateCount,
      'failed': failedItems,
    };
  }

  /// Helper to parse boolean from string
  bool _parseBool(String value) {
    final lower = value.toLowerCase().trim();
    return lower == 'true' || lower == 'yes' || lower == '1';
  }

  /// Export menu items to CSV
  Future<String> exportMenuItemsToCsv(List<MenuItem> menuItems) async {
    final List<List<dynamic>> rows = [
      // Header
      [
        'Name',
        'Description',
        'Price',
        'Category',
        'Allergens',
        'DietaryLabels',
        'PrepTimeMinutes',
        'IsAvailable',
      ],
      // Data rows
      ...menuItems.map((item) => [
            item.name,
            item.description,
            item.price.toStringAsFixed(2),
            item.category,
            item.allergens.join(', '),
            item.dietaryLabels.join(', '),
            item.prepTimeMinutes?.toString() ?? '',
            item.isAvailable ? 'TRUE' : 'FALSE',
          ]),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Export menu items to Excel
  Future<Uint8List> exportMenuItemsToExcel(List<MenuItem> menuItems) async {
    final excel = Excel.createExcel();
    final sheet = excel['Menu Items'];

    // Header
    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Description'),
      TextCellValue('Price'),
      TextCellValue('Category'),
      TextCellValue('Allergens'),
      TextCellValue('DietaryLabels'),
      TextCellValue('PrepTimeMinutes'),
      TextCellValue('IsAvailable'),
    ]);

    // Data rows
    for (final item in menuItems) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.description),
        DoubleCellValue(item.price),
        TextCellValue(item.category),
        TextCellValue(item.allergens.join(', ')),
        TextCellValue(item.dietaryLabels.join(', ')),
        TextCellValue(item.prepTimeMinutes?.toString() ?? ''),
        TextCellValue(item.isAvailable ? 'TRUE' : 'FALSE'),
      ]);
    }

    final excelBytes = excel.encode();
    return Uint8List.fromList(excelBytes!);
  }

  /// Import menu items from CSV (interface implementation)
  @override
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes) async {
    // TODO: Implement CSV import for menu items
    throw UnimplementedError('Menu item CSV import not yet implemented');
  }

  /// Export menu items to CSV (interface implementation)
  @override
  Future<List<int>> exportToCSV() async {
    final items = await getMenuItems().first;
    final csvString = await exportMenuItemsToCsv(items);
    return utf8.encode(csvString);
  }

  /// Import menu items from Excel (interface implementation)
  @override
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes) async {
    // TODO: Implement Excel import for menu items
    throw UnimplementedError('Menu item Excel import not yet implemented');
  }

  /// Export menu items to Excel (interface implementation)
  @override
  Future<List<int>> exportToExcel() async {
    final items = await getMenuItems().first;
    final excelBytes = await exportMenuItemsToExcel(items);
    return excelBytes;
  }
}
