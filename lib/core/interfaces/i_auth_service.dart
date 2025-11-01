import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

/// Interface for Authentication Service operations
/// 
/// This interface defines the contract for authentication operations.
abstract class IAuthService {
  /// Stream of authentication state changes
  Stream<User?> get authStateChanges;

  /// Get current user
  User? get currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password);

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle();

  /// Sign out
  Future<void> signOut();

  /// Get current user role
  Future<UserRole?> getCurrentUserRole();

  /// Check if current user is admin
  Future<bool> isAdmin();

  /// Check if current user is parent
  Future<bool> isParent();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Update user password
  Future<void> updatePassword(String newPassword);

  /// Delete user account
  Future<void> deleteAccount();

  /// Re-authenticate user
  Future<void> reauthenticateWithPassword(String password);
}
