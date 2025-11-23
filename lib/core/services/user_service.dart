import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../constants/database_constants.dart';
import '../interfaces/i_user_service.dart';

/// User Service - manages user records in Supabase database
/// 
/// This service handles the `users` table which stores basic account
/// information for ALL users (both admin and parent roles).
/// 
  /// The `users` table structure:
  /// ```
  /// users/
  ///   ├── id: uuid (Supabase Auth UUID, primary key)
  ///   ├── first_name: text
  ///   ├── last_name: text
  ///   ├── email: text (email address)
  ///   ├── is_admin: boolean (profile flag)
  ///   ├── is_parent: boolean (profile flag)
  ///   ├── created_at: timestamptz
  ///   ├── updated_at: timestamptz (nullable)
  ///   └── is_active: boolean
  /// ```
class UserService implements IUserService {
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  /// 
  /// [supabase] - Optional SupabaseClient instance for testing
  UserService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Get user by UID
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// 
  /// Returns: AppUser object or null if not found
  @override
  Future<AppUser?> getUser(String userId) async {
    try {
      final data = await _supabase
          .from(DatabaseConstants.usersTable)
          .select()
          .eq('uid', userId)
          .maybeSingle();

      if (data == null) return null;
      return AppUser.fromMap(data);
    } catch (e) {
      rethrow;
    }
  }  /// Get user stream (real-time updates)
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// 
  /// Returns: Stream of AppUser (null if not found)
  @override
  Stream<AppUser?> getUserStream(String userId) {
    return _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .eq('uid', userId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return AppUser.fromMap(rows.first);
        });
  }

  /// Send password reset email to a user's email address
  ///
  /// Admin-triggered helper: this uses the standard reset flow and does not
  /// require service role. Supabase will send the reset link to [email].
  /// Optionally provide a [redirectTo] URL to override the project default.
  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Create or update user document
  /// 
  /// This will upsert the data using the user's id.
  /// 
  /// Parameters:
  /// - user: The AppUser object to save
  Future<void> setUser(AppUser user) async {
    try {
      await _supabase
          .from(DatabaseConstants.usersTable)
          .upsert(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new user (interface implementation)
  @override
  Future<void> createUser(AppUser user) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .insert(user.toMap());
  }

  /// Update user information (interface implementation)
  @override
  Future<void> updateUser(AppUser user) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .update(user.toMap())
    .eq('uid', user.uid);
  }

  /// Delete user (interface implementation)
  @override
  Future<void> deleteUser(String uid) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .delete()
    .eq('uid', uid);
  }

  /// Check if user exists (interface implementation)
  @override
  Future<bool> userExists(String uid) async {
    final data = await _supabase
        .from(DatabaseConstants.usersTable)
        .select('uid')
        .eq('uid', uid)
        .maybeSingle();
    return data != null;
  }

  /// Get user's role
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// 
  /// Returns: UserRole enum value or null if user not found
  Future<UserRole?> getUserRole(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return null;

      // Give precedence to explicit profile flags.
      if (user.isAdmin) return UserRole.admin;
      if (user.isParent) return UserRole.parent;

      // Safe fallback: treat as parent (preserves previous behavior)
      return UserRole.parent;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user by email
  /// 
  /// Searches the users table for a user with the specified email.
  /// Returns null if no user is found.
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final data = await _supabase
          .from(DatabaseConstants.usersTable)
          .select()
          .eq('email', email)
          .maybeSingle();

      if (data != null) {
        return AppUser.fromMap(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is an admin
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// 
  /// Returns: true if user has admin role, false otherwise
  Future<bool> isAdmin(String userId) async {
    try {
      final user = await getUser(userId);
      return user?.isAdmin ?? false;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is a parent
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// 
  /// Returns: true if user has parent role, false otherwise
  Future<bool> isParent(String userId) async {
    try {
      final user = await getUser(userId);
      return user?.isParent ?? false;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user's role (admin-only operation)
  /// 
  /// This should only be called by administrators to change a user's role.
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  /// - role: The new role to assign
  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      final bool asAdmin = role == UserRole.admin;
      final bool asParent = role == UserRole.parent;

      await _supabase
          .from(DatabaseConstants.usersTable)
          .update({
            'is_admin': asAdmin,
            'is_parent': asParent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('uid', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate a user account (soft delete)
  /// 
  /// This sets is_active to false instead of deleting the document.
  /// Deactivated users cannot log in but their data is preserved.
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  @override
  Future<void> deactivateUser(String userId) async {
    try {
      await _supabase
          .from(DatabaseConstants.usersTable)
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('uid', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Activate a user account
  /// 
  /// This sets is_active to true, allowing the user to log in again.
  /// 
  /// Parameters:
  /// - userId: The Supabase Auth UUID
  @override
  Future<void> activateUser(String userId) async {
    try {
      await _supabase
          .from(DatabaseConstants.usersTable)
          .update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('uid', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all users with a specific role
  /// 
  /// Parameters:
  /// - role: The role to filter by
  /// - includeInactive: Whether to include deactivated users (default: false)
  /// 
  /// Returns: Stream of AppUser list
  @override
  Stream<List<AppUser>> getUsersByRole(
    UserRole role, {
    bool includeInactive = false,
  }) {
    final roleField = role == UserRole.admin ? 'is_admin' : 'is_parent';

    var query = _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .eq(roleField, true);

    return query.map((rows) {
      var users = rows.map((row) => AppUser.fromMap(row)).toList();

      // Filter inactive users if needed
      if (!includeInactive) {
        users = users.where((user) => user.isActive).toList();
      }

      return users;
    });
  }

  /// Get all active users
  ///
  /// Returns: Stream of all active AppUser objects
  Stream<List<AppUser>> getAllActiveUsers() {
    return _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .eq('is_active', true)
        .map((rows) => rows.map((row) => AppUser.fromMap(row)).toList());
  }

  /// Get all users (interface implementation)
  @override
  Stream<List<AppUser>> getAllUsers() {
    return _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .map((rows) => rows.map((row) => AppUser.fromMap(row)).toList());
  }

  /// Search users by email (interface implementation)
  @override
  Stream<List<AppUser>> searchUsersByEmail(String query) {
    return _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .map((rows) {
          final users = rows.map((row) => AppUser.fromMap(row)).toList();
          // Client-side filtering for case-insensitive search
          return users
              .where((user) => user.email.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
  }
}

