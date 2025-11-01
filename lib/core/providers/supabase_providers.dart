import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Provider for Supabase Client instance
/// 
/// This provider gives access to the Supabase client for database, auth, and storage operations.
/// Use this provider to inject Supabase into services for better testability.
/// 
/// Example usage:
/// ```dart
/// final studentServiceProvider = Provider<IStudentService>((ref) {
///   final supabase = ref.watch(supabaseProvider);
///   return StudentService(supabase: supabase);
/// });
/// ```
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

/// Alias for compatibility during migration
/// TODO: Remove after migration is complete
@Deprecated('Use supabaseProvider instead')
final firestoreProvider = supabaseProvider;

/// Alias for compatibility during migration  
/// TODO: Remove after migration is complete
@Deprecated('Use supabaseProvider instead')
final firebaseAuthProvider = supabaseProvider;

/// Alias for compatibility during migration
/// TODO: Remove after migration is complete
@Deprecated('Use supabaseProvider instead')
final firebaseStorageProvider = supabaseProvider;
