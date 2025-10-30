import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provider for FirebaseFirestore instance
/// 
/// This provider gives access to the Firestore database instance.
/// Use this provider to inject Firestore into services for better testability.
/// 
/// Example usage:
/// ```dart
/// final studentServiceProvider = Provider<IStudentService>((ref) {
///   final firestore = ref.watch(firestoreProvider);
///   return StudentService(firestore: firestore);
/// });
/// ```
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider for FirebaseAuth instance
/// 
/// This provider gives access to the Firebase Authentication instance.
/// Use this provider to inject Auth into services for better testability.
/// 
/// Example usage:
/// ```dart
/// final authServiceProvider = Provider<IAuthService>((ref) {
///   final auth = ref.watch(firebaseAuthProvider);
///   return AuthService(auth: auth, ...);
/// });
/// ```
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for FirebaseStorage instance
/// 
/// This provider gives access to the Firebase Storage instance.
/// Use this provider to inject Storage into services for better testability.
/// 
/// Example usage:
/// ```dart
/// final storageServiceProvider = Provider<IStorageService>((ref) {
///   final storage = ref.watch(firebaseStorageProvider);
///   return StorageService(storage: storage);
/// });
/// ```
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// Provider for GoogleSignIn instance
/// 
/// This provider gives access to the Google Sign-In instance.
/// Use this provider to inject GoogleSignIn into services for better testability.
/// 
/// Example usage:
/// ```dart
/// final authServiceProvider = Provider<IAuthService>((ref) {
///   final googleSignIn = ref.watch(googleSignInProvider);
///   return AuthService(googleSignIn: googleSignIn, ...);
/// });
/// ```
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn();
});
