import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'supabase_providers.dart';

// ============================================================================
// STORAGE SERVICE PROVIDER
// ============================================================================

/// Storage Service Provider
/// 
/// Handles file uploads to Supabase Storage (images, documents).
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    supabase: ref.watch(supabaseProvider),
  );
});
