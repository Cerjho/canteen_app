// ============================================================================
// APP PROVIDERS - CENTRAL EXPORT FILE
// ============================================================================
//
// This file exports all domain-specific provider files for easy import
// throughout the application.
//
// Usage:
//   import 'package:canteen_app/core/providers/app_providers.dart';
//
// Domain-specific providers are organized in separate files:
// - supabase_providers.dart: Supabase client instances (Database, Auth, Storage)
// - auth_providers.dart: Authentication and user management
// - user_providers.dart: Student and parent management  
// - menu_providers.dart: Menu items and weekly menu scheduling
// - transaction_providers.dart: Orders and top-up requests
// - storage_providers.dart: File upload and storage
//
// ============================================================================

// Export all domain-specific provider files
export 'supabase_providers.dart';
export 'auth_providers.dart';
export 'user_providers.dart';
export 'menu_providers.dart';
export 'transaction_providers.dart';
export 'storage_providers.dart';
export 'analytics_range_provider.dart';
export 'cart_provider.dart';
export 'date_refresh_provider.dart';
export 'day_of_order_provider.dart';
export '../services/cart_persistence_service.dart';


