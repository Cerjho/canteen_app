import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

/// Storage Service - handles file uploads to Firebase Storage
class StorageService {
  final FirebaseStorage _storage;

  /// Constructor with dependency injection
  StorageService({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  /// Upload image file
  Future<String> uploadImage({
    required Uint8List imageData,
    required String path,
    required String fileName,
  }) async {
    try {
      // Create reference
      final ref = _storage.ref().child('$path/$fileName');

      // Upload file
      final uploadTask = ref.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
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
        await deleteFile(oldImageUrl);
      } catch (e) {
        // Ignore delete errors, continue with upload
      }
    }

    // Generate unique filename to prevent caching issues
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${menuItemId}_$timestamp.jpg';

    return uploadImage(
      imageData: imageData,
      path: 'menu_items',
      fileName: fileName,
    );
  }

  /// Upload student photo
  Future<String> uploadStudentPhoto(Uint8List imageData, String studentId) async {
    return uploadImage(
      imageData: imageData,
      path: 'students',
      fileName: '$studentId.jpg',
    );
  }

  /// Upload parent photo
  Future<String> uploadParentPhoto(Uint8List imageData, String parentId) async {
    return uploadImage(
      imageData: imageData,
      path: 'parents',
      fileName: '$parentId.jpg',
    );
  }

  /// Upload topup proof
  Future<String> uploadTopupProof(Uint8List imageData, String topupId) async {
    return uploadImage(
      imageData: imageData,
      path: 'topup_proofs',
      fileName: '$topupId.jpg',
    );
  }

  /// Delete file from storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete menu item image
  Future<void> deleteMenuItemImage(String downloadUrl) async {
    await deleteFile(downloadUrl);
  }
}
