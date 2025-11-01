import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'firebase_providers.dart';

// ============================================================================
// STORAGE SERVICE PROVIDER
// ============================================================================

/// Storage Service Provider
/// 
/// Handles file uploads to Firebase Storage (images, documents).
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    storage: ref.watch(firebaseStorageProvider),
  );
});
