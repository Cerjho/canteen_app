/// Database constants for table names, field names, and operation limits
class DatabaseConstants {
  // Private constructor to prevent instantiation
  DatabaseConstants._();

  // ==================== TABLE NAMES ====================
  
  /// Table name for students
  static const String studentsTable = 'students';
  
  /// Table name for parents
  static const String parentsTable = 'parents';
  
  /// Table name for menu items
  static const String menuItemsTable = 'menu_items';
  
  /// Table name for weekly menus
  static const String weeklyMenusTable = 'weekly_menus';
  
  /// Table name for menu analytics
  static const String menuAnalyticsTable = 'weekly_menu_analytics';
  
  /// Table name for weekly menu analytics (alias)
  static const String weeklyMenuAnalyticsTable = 'weekly_menu_analytics';
  
  /// Table name for orders
  static const String ordersTable = 'orders';
  
  /// Table name for top-ups
  static const String topupsTable = 'topup_requests';
  
  /// Table name for users
  static const String usersTable = 'users';
  
  /// Table name for parent transactions
  static const String transactionsTable = 'parent_transactions';

  // ==================== COMMON FIELD NAMES ====================
  
  /// Field name for document ID
  static const String id = 'id';
  
  /// Field name for parent ID (foreign key)
  static const String parentId = 'parent_id';
  
  /// Field name for student ID (foreign key)
  static const String studentId = 'student_id';
  
  /// Field name for user ID (foreign key)
  static const String userId = 'user_id';
  
  /// Field name for balance
  static const String balance = 'balance';
  
  /// Field name for active status
  static const String isActive = 'is_active';
  
  /// Field name for available status
  static const String isAvailable = 'is_available';
  
  /// Field name for available days (menu items)
  static const String availableDays = 'available_days';
  
  /// Field name for published status
  static const String isPublished = 'is_published';
  
  /// Field name for creation timestamp
  static const String createdAt = 'created_at';
  
  /// Field name for update timestamp
  static const String updatedAt = 'updated_at';
  
  /// Field name for calculated timestamp (analytics)
  static const String calculatedAt = 'calculated_at';
  
  /// Field name for order date
  static const String orderDate = 'order_date';
  
  /// Field name for request date
  static const String requestDate = 'request_date';
  
  /// Field name for published date
  static const String publishedAt = 'published_at';
  
  /// Field name for status
  static const String status = 'status';
  
  /// Field name for role
  static const String role = 'role';

  // ==================== STUDENT FIELDS ====================
  
  /// Field name for student first name
  static const String firstName = 'first_name';
  
  /// Field name for student last name
  static const String lastName = 'last_name';
  
  /// Field name for student grade
  static const String grade = 'grade';
  
  /// Field name for student allergies
  static const String allergies = 'allergies';
  
  /// Field name for dietary restrictions
  static const String dietaryRestrictions = 'dietary_restrictions';
  
  /// Field name for photo URL
  static const String photoUrl = 'photo_url';

  // ==================== MENU ITEM FIELDS ====================
  
  /// Field name for menu item name
  static const String name = 'name';
  
  /// Field name for menu item description
  static const String description = 'description';
  
  /// Field name for menu item price
  static const String price = 'price';
  
  /// Field name for menu item category
  static const String category = 'category';
  
  /// Field name for menu item image URL
  static const String imageUrl = 'image_url';
  
  /// Field name for allergens list
  static const String allergens = 'allergens';
  
  /// Field name for vegetarian status
  static const String isVegetarian = 'is_vegetarian';
  
  /// Field name for vegan status
  static const String isVegan = 'is_vegan';
  
  /// Field name for gluten-free status
  static const String isGlutenFree = 'is_gluten_free';
  
  /// Field name for stock quantity
  static const String stockQuantity = 'stock_quantity';

  // ==================== ORDER FIELDS ====================
  
  /// Field name for student name
  static const String studentName = 'student_name';
  
  /// Field name for parent name
  static const String parentName = 'parent_name';
  
  /// Field name for order items
  static const String items = 'items';
  
  /// Field name for menu item ID
  static const String menuItemId = 'menu_item_id';
  
  /// Field name for meal type
  static const String mealType = 'meal_type';
  
  /// Field name for quantity
  static const String quantity = 'quantity';
  
  /// Field name for total amount
  static const String totalAmount = 'total_amount';
  
  /// Field name for notes
  static const String notes = 'notes';

  // ==================== WEEKLY MENU FIELDS ====================
  
  /// Field name for week start date
  static const String weekStartDate = 'week_start_date';
  
  /// Field name for menu by day structure
  static const String menuByDay = 'menu_by_day';
  
  /// Field name for copied from week
  static const String copiedFromWeek = 'copied_from_week';
  
  /// Field name for published by (admin ID)
  static const String publishedBy = 'published_by';

  // ==================== DATABASE OPERATION LIMITS ====================
  
  /// Maximum items allowed in Postgres 'IN' queries
  static const int inQueryLimit = 1000;
  
  /// Default page size for paginated queries
  static const int defaultPageSize = 10;
  
  /// Maximum page size for paginated queries
  static const int maxPageSize = 100;
  
  /// Maximum items to process in a single batch operation
  static const int maxBatchSize = 1000;
}
