import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

/// Storage Service - handles file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  StorageService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Upload image file
  Future<String> uploadImage({
    required Uint8List imageData,
    required String bucket,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    try {
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            imageData,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload menu item image with unique filename
  Future<String> uploadMenuItemImage(
    Uint8List imageData,
    String menuItemId, {
    String? oldImageUrl,
  }) async {
    // Delete old image if exists
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      try {
        await deleteFileByUrl(oldImageUrl);
      } catch (e) {
        // Ignore delete errors, continue with upload
      }
    }

    // Generate unique filename to prevent caching issues
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${menuItemId}_$timestamp.jpg';
    final path = 'menu_items/$fileName';

    return uploadImage(
      imageData: imageData,
      bucket: 'images',
      path: path,
    );
  }

  /// Upload student photo
  Future<String> uploadStudentPhoto(Uint8List imageData, String studentId) async {
    final path = 'students/$studentId.jpg';
    return uploadImage(
      imageData: imageData,
      bucket: 'images',
      path: path,
    );
  }

  /// Upload parent photo
  Future<String> uploadParentPhoto(Uint8List imageData, String parentId) async {
    final path = 'parents/$parentId.jpg';
    return uploadImage(
      imageData: imageData,
      bucket: 'images',
      path: path,
    );
  }

  /// Upload topup proof
  Future<String> uploadTopupProof(Uint8List imageData, String topupId) async {
    final path = 'topup_proofs/$topupId.jpg';
    return uploadImage(
      imageData: imageData,
      bucket: 'documents',
      path: path,
    );
  }

  /// Delete file from storage by URL
  Future<void> deleteFileByUrl(String publicUrl) async {
    try {
      // Extract the file path from the public URL
      // Supabase public URL format: https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      
      // Find 'public' segment and extract bucket and path
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex == -1 || publicIndex + 1 >= pathSegments.length) {
        throw Exception('Invalid storage URL format');
      }
      
      final bucket = pathSegments[publicIndex + 1];
      final filePath = pathSegments.sublist(publicIndex + 2).join('/');
      
      await _supabase.storage
          .from(bucket)
          .remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _supabase.storage
          .from(bucket)
          .remove([path]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete menu item image
  Future<void> deleteMenuItemImage(String downloadUrl) async {
    await deleteFileByUrl(downloadUrl);
  }
}
