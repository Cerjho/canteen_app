import '../models/menu_item.dart';

/// Interface for Menu Service operations
/// 
/// This interface defines the contract for menu item-related operations.
abstract class IMenuService {
  /// Get all menu items as a stream
  Stream<List<MenuItem>> getMenuItems();

  /// Get available menu items only
  Stream<List<MenuItem>> getAvailableMenuItems();

  /// Get menu item by ID
  Future<MenuItem?> getMenuItemById(String id);

  /// Get menu item stream by ID
  Stream<MenuItem?> getMenuItemStream(String id);

  /// Create a new menu item
  Future<void> addMenuItem(MenuItem menuItem);

  /// Update an existing menu item
  Future<void> updateMenuItem(MenuItem menuItem);

  /// Delete a menu item
  Future<void> deleteMenuItem(String id);

  /// Toggle menu item availability
  Future<void> toggleAvailability(String id, bool isAvailable);

  /// Update menu item stock quantity
  Future<void> updateStockQuantity(String id, int quantity);

  /// Get menu items by category
  Stream<List<MenuItem>> getMenuItemsByCategory(String category);

  /// Get menu items by availability for specific days
  Stream<List<MenuItem>> getMenuItemsByAvailableDays(List<String> days);

  /// Search menu items by name
  Stream<List<MenuItem>> searchMenuItems(String query);

  /// Get menu items for breakfast
  Stream<List<MenuItem>> getBreakfastItems();

  /// Get menu items for lunch
  Stream<List<MenuItem>> getLunchItems();

  /// Get menu items for snacks
  Stream<List<MenuItem>> getSnackItems();

  /// Get drinks
  Stream<List<MenuItem>> getDrinks();

  /// Import menu items from CSV
  Future<Map<String, dynamic>> importFromCSV(List<int> bytes);

  /// Export menu items to CSV
  Future<List<int>> exportToCSV();

  /// Import menu items from Excel
  Future<Map<String, dynamic>> importFromExcel(List<int> bytes);

  /// Export menu items to Excel
  Future<List<int>> exportToExcel();
}
