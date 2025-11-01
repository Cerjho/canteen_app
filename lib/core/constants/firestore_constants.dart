/// Firestore constants for collection names, field names, and operation limits
class FirestoreConstants {
  // Private constructor to prevent instantiation
  FirestoreConstants._();

  // ==================== COLLECTION NAMES ====================
  
  /// Collection name for students
  static const String studentsCollection = 'students';
  
  /// Collection name for parents
  static const String parentsCollection = 'parents';
  
  /// Collection name for menu items
  static const String menuItemsCollection = 'menu_items';
  
  /// Collection name for weekly menus
  static const String weeklyMenusCollection = 'weekly_menus';
  
  /// Collection name for menu analytics
  static const String menuAnalyticsCollection = 'menu_analytics';
  
  /// Collection name for weekly menu analytics (alias)
  static const String weeklyMenuAnalyticsCollection = 'weekly_menu_analytics';
  
  /// Collection name for orders
  static const String ordersCollection = 'orders';
  
  /// Collection name for top-ups
  static const String topupsCollection = 'topups';
  
  /// Collection name for users
  static const String usersCollection = 'users';

  // ==================== COMMON FIELD NAMES ====================
  
  /// Field name for document ID
  static const String id = 'id';
  
  /// Field name for parent ID (foreign key)
  static const String parentId = 'parentId';
  
  /// Field name for student ID (foreign key)
  static const String studentId = 'studentId';
  
  /// Field name for user ID (foreign key)
  static const String userId = 'userId';
  
  /// Field name for balance
  static const String balance = 'balance';
  
  /// Field name for active status
  static const String isActive = 'isActive';
  
  /// Field name for available status
  static const String isAvailable = 'isAvailable';
  
  /// Field name for available days (menu items)
  static const String availableDays = 'availableDays';
  
  /// Field name for published status
  static const String isPublished = 'isPublished';
  
  /// Field name for creation timestamp
  static const String createdAt = 'createdAt';
  
  /// Field name for update timestamp
  static const String updatedAt = 'updatedAt';
  
  /// Field name for calculated timestamp (analytics)
  static const String calculatedAt = 'calculatedAt';
  
  /// Field name for order date
  static const String orderDate = 'orderDate';
  
  /// Field name for request date
  static const String requestDate = 'requestDate';
  
  /// Field name for published date
  static const String publishedAt = 'publishedAt';
  
  /// Field name for status
  static const String status = 'status';
  
  /// Field name for role
  static const String role = 'role';

  // ==================== STUDENT FIELDS ====================
  
  /// Field name for student first name
  static const String firstName = 'firstName';
  
  /// Field name for student last name
  static const String lastName = 'lastName';
  
  /// Field name for student grade
  static const String grade = 'grade';
  
  /// Field name for student allergies
  static const String allergies = 'allergies';
  
  /// Field name for dietary restrictions
  static const String dietaryRestrictions = 'dietaryRestrictions';
  
  /// Field name for photo URL
  static const String photoUrl = 'photoUrl';

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
  static const String imageUrl = 'imageUrl';
  
  /// Field name for allergens list
  static const String allergens = 'allergens';
  
  /// Field name for vegetarian status
  static const String isVegetarian = 'isVegetarian';
  
  /// Field name for vegan status
  static const String isVegan = 'isVegan';
  
  /// Field name for gluten-free status
  static const String isGlutenFree = 'isGlutenFree';
  
  /// Field name for stock quantity
  static const String stockQuantity = 'stockQuantity';

  // ==================== ORDER FIELDS ====================
  
  /// Field name for student name
  static const String studentName = 'studentName';
  
  /// Field name for parent name
  static const String parentName = 'parentName';
  
  /// Field name for order items
  static const String items = 'items';
  
  /// Field name for menu item ID
  static const String menuItemId = 'menuItemId';
  
  /// Field name for meal type
  static const String mealType = 'mealType';
  
  /// Field name for quantity
  static const String quantity = 'quantity';
  
  /// Field name for total amount
  static const String totalAmount = 'totalAmount';
  
  /// Field name for notes
  static const String notes = 'notes';

  // ==================== WEEKLY MENU FIELDS ====================
  
  /// Field name for week start date
  static const String weekStartDate = 'weekStartDate';
  
  /// Field name for menu by day structure
  static const String menuByDay = 'menuByDay';
  
  /// Field name for copied from week
  static const String copiedFromWeek = 'copiedFromWeek';
  
  /// Field name for published by (admin ID)
  static const String publishedBy = 'publishedBy';

  // ==================== FIRESTORE OPERATION LIMITS ====================
  
  /// Maximum items allowed in Firestore 'whereIn' or 'arrayContains' queries
  static const int inQueryLimit = 30;
  
  /// Maximum operations per batch commit
  static const int batchOperationLimit = 500;
  
  /// Default page size for paginated queries
  static const int defaultPageSize = 10;
  
  /// Maximum page size for paginated queries
  static const int maxPageSize = 50;
  
  /// Maximum items to process in a single batch operation
  static const int maxBatchSize = 500;
}
