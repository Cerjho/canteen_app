// ============================================================================
// APP PROVIDERS - CENTRAL EXPORT FILE
// ============================================================================
//
// This file exports all domain-specific provider files for easy import
// throughout the application.
//
// Usage:
//   import 'package:admin_app/core/providers/app_providers.dart';
//
// Domain-specific providers are organized in separate files:
// - firebase_providers.dart: Firebase service instances (Firestore, Auth, Storage, GoogleSignIn)
// - auth_providers.dart: Authentication and user management
// - user_providers.dart: Student and parent management
// - menu_providers.dart: Menu items and weekly menu scheduling
// - transaction_providers.dart: Orders and top-up requests
// - storage_providers.dart: File upload and storage
//
// ============================================================================

// Export all domain-specific provider files
export 'firebase_providers.dart';
export 'auth_providers.dart';
export 'user_providers.dart';
export 'menu_providers.dart';
export 'transaction_providers.dart';
export 'storage_providers.dart';


