import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import '../constants/firestore_constants.dart';
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
  final FirebaseFirestore _firestore;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  MenuService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all menu items
  @override
  Stream<List<MenuItem>> getMenuItems() {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .orderBy(FirestoreConstants.createdAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MenuItem.fromMap(doc.data())).toList());
  }

  /// Get available menu items only
  @override
  Stream<List<MenuItem>> getAvailableMenuItems() {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .where(FirestoreConstants.isAvailable, isEqualTo: true)
        .orderBy(FirestoreConstants.createdAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MenuItem.fromMap(doc.data())).toList());
  }

  /// Get menu items by category
  @override
  Stream<List<MenuItem>> getMenuItemsByCategory(String category) {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .where(FirestoreConstants.category, isEqualTo: category)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MenuItem.fromMap(doc.data())).toList());
  }

  /// Get menu item by ID
  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    final doc = await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return MenuItem.fromMap(doc.data()!);
    }
    return null;
  }

  /// Get menu item stream by ID
  @override
  Stream<MenuItem?> getMenuItemStream(String id) {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .doc(id)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists && snapshot.data() != null ? MenuItem.fromMap(snapshot.data()!) : null);
  }

  /// Create a new menu item (Alias for createMenuItem)
  @override
  Future<void> addMenuItem(MenuItem menuItem) async {
    // Check for duplicate by name (case-insensitive)
    final existingItem = await _checkDuplicateByName(menuItem.name);
    if (existingItem != null) {
      throw Exception('A menu item with the name "${menuItem.name}" already exists.');
    }
    
    await _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .doc(menuItem.id)
        .set(menuItem.toMap());
  }

  /// Create a new menu item
  Future<void> createMenuItem(MenuItem menuItem) async {
    await addMenuItem(menuItem);
  }

  /// Check if a menu item with the same name exists
  Future<MenuItem?> _checkDuplicateByName(String name) async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return MenuItem.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  /// Update menu item
  @override
  Future<void> updateMenuItem(MenuItem menuItem) async {
    final updatedMenuItem = menuItem.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .doc(menuItem.id)
        .update(updatedMenuItem.toMap());
  }

  /// Delete menu item
  @override
  Future<void> deleteMenuItem(String id) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(id).delete();
  }

  /// Toggle menu item availability (interface implementation)
  @override
  Future<void> toggleAvailability(String menuItemId, bool isAvailable) async {
    await updateAvailability(menuItemId, isAvailable);
  }

  /// Toggle menu item availability (legacy method - auto-toggles)
  Future<void> toggleAvailabilityAuto(String menuItemId) async {
    final doc = await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItemId).get();
    if (doc.exists && doc.data() != null) {
      final currentAvailability = doc.data()!['isAvailable'] as bool? ?? true;
      await updateAvailability(menuItemId, !currentAvailability);
    }
  }

  /// Update menu item availability
  Future<void> updateAvailability(String menuItemId, bool isAvailable) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItemId).update({
      'isAvailable': isAvailable,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Update stock quantity
  @override
  Future<void> updateStockQuantity(String id, int quantity) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(id).update({
      FirestoreConstants.stockQuantity: quantity,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Update stock (legacy method - alias)
  Future<void> updateStock(String menuItemId, int quantity) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItemId).update({
      FirestoreConstants.stockQuantity: quantity,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Delete menu item image from storage and update Firestore
  Future<void> deleteMenuItemImage(String menuItemId) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItemId).update({
      'imageUrl': null,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Update menu item image URL
  Future<void> updateMenuItemImage(String menuItemId, String imageUrl) async {
    await _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItemId).update({
      'imageUrl': imageUrl,
      FirestoreConstants.updatedAt: Timestamp.now(),
    });
  }

  /// Get menu items by available days
  @override
  Stream<List<MenuItem>> getMenuItemsByAvailableDays(List<String> days) {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .where('availableDays', arrayContainsAny: days)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MenuItem.fromMap(doc.data())).toList());
  }

  /// Get breakfast items
  @override
  Stream<List<MenuItem>> getBreakfastItems() {
    return getMenuItemsByCategory('Breakfast');
  }

  /// Get lunch items
  @override
  Stream<List<MenuItem>> getLunchItems() {
    return getMenuItemsByCategory('Lunch');
  }

  /// Get snack items
  @override
  Stream<List<MenuItem>> getSnackItems() {
    return getMenuItemsByCategory('Snacks');
  }

  /// Get drinks
  @override
  Stream<List<MenuItem>> getDrinks() {
    return getMenuItemsByCategory('Drinks');
  }

  /// Search menu items by name
  @override
  Stream<List<MenuItem>> searchMenuItems(String query) {
    return _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MenuItem.fromMap(doc.data()))
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  /// Get menu categories
  Future<List<String>> getCategories() async {
    final snapshot = await _firestore.collection(FirestoreConstants.menuItemsCollection).get();
    final categories = snapshot.docs
        .map((doc) => doc.data()['category'] as String)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  /// Get menu items count
  Future<int> getMenuItemsCount() async {
    final snapshot = await _firestore.collection(FirestoreConstants.menuItemsCollection).count().get();
    return snapshot.count ?? 0;
  }

  /// Get available menu items count
  Future<int> getAvailableMenuItemsCount() async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.menuItemsCollection)
        .where(FirestoreConstants.isAvailable, isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
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
    final isVegetarianIdx = headers.indexOf('isvegetarian');
    final isVeganIdx = headers.indexOf('isvegan');
    final isGlutenFreeIdx = headers.indexOf('isglutenfree');
    final stockQuantityIdx = headers.indexOf('stockquantity');

    if (nameIdx == -1 || descriptionIdx == -1 || priceIdx == -1 || categoryIdx == -1) {
      throw Exception(
          'CSV must contain required columns: name, description, price, category');
    }

    // Fetch existing menu items to check duplicates
    final existingSnapshot = await _firestore.collection(FirestoreConstants.menuItemsCollection).get();
    final existingNames =
        existingSnapshot.docs.map((doc) => doc.data()['name'] as String).toSet();

    // Use WriteBatch for efficient batch writes (max 500 operations)
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

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

        final isVegetarian = isVegetarianIdx != -1 && isVegetarianIdx < row.length
            ? _parseBool(row[isVegetarianIdx].toString())
            : false;
        final isVegan = isVeganIdx != -1 && isVeganIdx < row.length
            ? _parseBool(row[isVeganIdx].toString())
            : false;
        final isGlutenFree = isGlutenFreeIdx != -1 && isGlutenFreeIdx < row.length
            ? _parseBool(row[isGlutenFreeIdx].toString())
            : false;

        final stockQuantityStr = stockQuantityIdx != -1 && stockQuantityIdx < row.length
            ? row[stockQuantityIdx].toString().trim()
            : '';
        final stockQuantity = stockQuantityStr.isNotEmpty ? int.tryParse(stockQuantityStr) : null;

        // Create menu item
        final menuItem = MenuItem(
          id: uuid.v4(),
          name: name,
          description: description,
          price: price,
          category: category,
          allergens: allergens,
          isVegetarian: isVegetarian,
          isVegan: isVegan,
          isGlutenFree: isGlutenFree,
          isAvailable: true,
          stockQuantity: stockQuantity,
          createdAt: DateTime.now(),
        );

        // Add to batch
        batch.set(
          _firestore.collection(FirestoreConstants.menuItemsCollection).doc(menuItem.id),
          menuItem.toMap(),
        );
        batchCount++;
        successCount++;
        existingNames.add(name); // Prevent duplicates within same import

        // Commit batch if reaching limit (500 operations)
        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      } catch (e) {
        failedItems.add({
          'row': i + 2,
          'error': e.toString(),
        });
      }
    }

    // Commit remaining operations
    if (batchCount > 0) {
      await batch.commit();
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
        'IsVegetarian',
        'IsVegan',
        'IsGlutenFree',
        'IsAvailable',
        'StockQuantity',
      ],
      // Data rows
      ...menuItems.map((item) => [
            item.name,
            item.description,
            item.price.toStringAsFixed(2),
            item.category,
            item.allergens.join(', '),
            item.isVegetarian ? 'TRUE' : 'FALSE',
            item.isVegan ? 'TRUE' : 'FALSE',
            item.isGlutenFree ? 'TRUE' : 'FALSE',
            item.isAvailable ? 'TRUE' : 'FALSE',
            item.stockQuantity?.toString() ?? '',
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
      TextCellValue('IsVegetarian'),
      TextCellValue('IsVegan'),
      TextCellValue('IsGlutenFree'),
      TextCellValue('IsAvailable'),
      TextCellValue('StockQuantity'),
    ]);

    // Data rows
    for (final item in menuItems) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.description),
        DoubleCellValue(item.price),
        TextCellValue(item.category),
        TextCellValue(item.allergens.join(', ')),
        TextCellValue(item.isVegetarian ? 'TRUE' : 'FALSE'),
        TextCellValue(item.isVegan ? 'TRUE' : 'FALSE'),
        TextCellValue(item.isGlutenFree ? 'TRUE' : 'FALSE'),
        TextCellValue(item.isAvailable ? 'TRUE' : 'FALSE'),
        TextCellValue(item.stockQuantity?.toString() ?? ''),
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
