import '../models/user_role.dart';

/// Interface for User Service operations
/// 
/// This interface defines the contract for user account operations.
abstract class IUserService {
  /// Get user by ID
  Future<AppUser?> getUser(String uid);

  /// Get user stream by ID
  Stream<AppUser?> getUserStream(String uid);

  /// Create a new user
  Future<void> createUser(AppUser user);

  /// Update user information
  Future<void> updateUser(AppUser user);

  /// Delete user
  Future<void> deleteUser(String uid);

  /// Update user role
  Future<void> updateUserRole(String uid, UserRole role);

  /// Activate user account
  Future<void> activateUser(String uid);

  /// Deactivate user account
  Future<void> deactivateUser(String uid);

  /// Check if user exists
  Future<bool> userExists(String uid);

  /// Get all users
  Stream<List<AppUser>> getAllUsers();

  /// Get users by role
  Stream<List<AppUser>> getUsersByRole(UserRole role);

  /// Search users by email
  Stream<List<AppUser>> searchUsersByEmail(String query);
}
