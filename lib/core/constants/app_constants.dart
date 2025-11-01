/// UI Constants for consistent sizing and timing across the app
class UIConstants {
  // Dialog dimensions
  static const double dialogWidthSmall = 400.0;
  static const double dialogWidthMedium = 600.0;
  static const double dialogWidthLarge = 800.0;
  
  // Card dimensions
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 12.0;
  
  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Grid columns
  static const int gridColumnsMobile = 2;
  static const int gridColumnsTablet = 3;
  static const int gridColumnsDesktop = 4;
  
  // Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;
  
  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Delays
  static const Duration uiUpdateDelay = Duration(milliseconds: 300);
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration snackbarLongDuration = Duration(seconds: 5);
  
  // Image sizes
  static const double imageSize = 200.0;
  static const double thumbnailSize = 80.0;
  static const double avatarSize = 40.0;
  static const double avatarSizeLarge = 60.0;
  
  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  // Border radius
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;
  
  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Font sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeTitle = 24.0;
  static const double fontSizeHeading = 32.0;
  
  // Max widths
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 600.0;
  
  // Table
  static const int defaultRowsPerPage = 10;
  static const List<int> rowsPerPageOptions = [10, 25, 50, 100];
}

/// App-wide configuration constants
class AppConstants {
  // App info
  static const String appName = 'Canteen Admin';
  static const String appVersion = '0.1.0';
  
  // Firestore collection names
  static const String studentsCollection = 'students';
  static const String parentsCollection = 'parents';
  static const String menuItemsCollection = 'menu_items';
  static const String ordersCollection = 'orders';
  static const String topupsCollection = 'topups';
  static const String weeklyMenusCollection = 'weekly_menus';
  static const String weeklyMenuAnalyticsCollection = 'weekly_menu_analytics';
  static const String settingsCollection = 'settings';
  
  // Storage paths
  static const String menuItemsStoragePath = 'menu_items';
  static const String studentsStoragePath = 'students';
  static const String parentsStoragePath = 'parents';
  static const String topupsStoragePath = 'topups';
  
  // Grades
  static const List<String> grades = [
    'Nursery',
    'Pre-Kinder',
    'Kindergarten',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
  ];
  
  // Menu categories
  static const List<String> menuCategories = [
    'Lunch',
    'Snacks',
    'Drinks',
    'Desserts',
    'Combo Meals',
    'Special Items',
  ];
  
  // Order statuses
  static const String orderStatusPending = 'pending';
  static const String orderStatusConfirmed = 'confirmed';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';
  
  // Top-up statuses
  static const String topupStatusPending = 'pending';
  static const String topupStatusApproved = 'approved';
  static const String topupStatusDeclined = 'declined';
  
  // Payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'GCash',
    'PayMaya',
    'Bank Transfer',
    'Credit Card',
  ];
  
  // Meal types
  static const String mealTypeMorningSnack = 'morning_snack';
  static const String mealTypeLunch = 'lunch';
  static const String mealTypeAfternoonSnack = 'afternoon_snack';
  
  // Meal type limits (for weekly menu)
  static const int morningSnackLimit = 2;
  static const int lunchLimit = 2;
  static const int afternoonSnackLimit = 2;
  
  // Days of the week
  static const List<String> weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  
  // Currency
  static const String currencySymbol = '₱';
  static const String currencyCode = 'PHP';
  
  // Validation limits
  static const double minPrice = 0.01;
  static const double maxPrice = 10000.0;
  static const double minBalance = 0.0;
  static const double maxBalance = 100000.0;
  static const int minStockQuantity = 0;
  static const int maxStockQuantity = 10000;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Image constraints
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  
  // CSV/Excel export
  static const String exportDateFormat = 'yyyy-MM-dd_HHmmss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';
  static const String displayDateTimeFormat = 'MMM dd, yyyy hh:mm a';
  
  // Analytics
  static const int topItemsCount = 5;
  static const int testOrdersCount = 120;
  
  // Error messages
  static const String errorGeneric = 'An error occurred. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorAuth = 'Authentication error. Please log in again.';
  static const String errorPermission = 'You don\'t have permission to perform this action.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorDuplicate = 'This item already exists.';
  static const String errorValidation = 'Please check your input and try again.';
  
  // Success messages
  static const String successCreate = 'Created successfully';
  static const String successUpdate = 'Updated successfully';
  static const String successDelete = 'Deleted successfully';
  static const String successUpload = 'Uploaded successfully';
  
  // Confirmation messages
  static const String confirmDelete = 'Are you sure you want to delete this item?';
  static const String confirmCancel = 'Are you sure you want to cancel? Unsaved changes will be lost.';
  static const String confirmLogout = 'Are you sure you want to log out?';
  
  // Firestore query limits
  static const int firestoreQueryLimit = 500;
  static const int firestoreBatchSize = 500;
  
  // Cache durations
  static const Duration cacheShortDuration = Duration(minutes: 5);
  static const Duration cacheMediumDuration = Duration(minutes: 30);
  static const Duration cacheLongDuration = Duration(hours: 24);
}
