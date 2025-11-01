import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';
import '../constants/firestore_constants.dart';
import '../interfaces/i_user_service.dart';

/// User Service - manages user documents in Firestore
/// 
/// This service handles the `users` collection which stores basic account
/// information for ALL users (both admin and parent roles).
/// 
  /// The `users` collection structure:
  /// ```
  /// users/{uid}/
  ///   ├── uid: string (Firebase Auth UID)
  ///   ├── firstName: string
  ///   ├── lastName: string
  ///   ├── email: string (email address)
  ///   ├── isAdmin: boolean (profile flag)
  ///   ├── isParent: boolean (profile flag)
  ///   ├── createdAt: timestamp
  ///   ├── updatedAt: timestamp (nullable)
  ///   └── isActive: boolean
  /// ```
class UserService implements IUserService {
  final FirebaseFirestore _firestore;

  /// Constructor with dependency injection
  /// 
  /// [firestore] - Optional FirebaseFirestore instance for testing
  UserService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get user by UID
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
  /// 
  /// Returns: AppUser object or null if not found
  @override
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(FirestoreConstants.usersCollection).doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get user stream (real-time updates)
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
  /// 
  /// Returns: Stream of AppUser (null if not found)
  @override
  Stream<AppUser?> getUserStream(String userId) {
    return _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    });
  }

  /// Create or update user document
  /// 
  /// This will merge with existing data if the document exists.
  /// 
  /// Parameters:
  /// - user: The AppUser object to save
  Future<void> setUser(AppUser user) async {
    try {
      await _firestore
          .collection(FirestoreConstants.usersCollection)
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new user (interface implementation)
  @override
  Future<void> createUser(AppUser user) async {
    await setUser(user);
  }

  /// Update user information (interface implementation)
  @override
  Future<void> updateUser(AppUser user) async {
    await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(user.uid)
        .update(user.toMap());
  }

  /// Delete user (interface implementation)
  @override
  Future<void> deleteUser(String uid) async {
    await _firestore.collection(FirestoreConstants.usersCollection).doc(uid).delete();
  }

  /// Check if user exists (interface implementation)
  @override
  Future<bool> userExists(String uid) async {
    final doc = await _firestore.collection(FirestoreConstants.usersCollection).doc(uid).get();
    return doc.exists;
  }

  /// Get user's role
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
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
  /// Searches the users collection for a user with the specified email.
  /// Returns null if no user is found.
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return AppUser.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is an admin
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
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
  /// - userId: The Firebase Auth UID
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
  /// - userId: The Firebase Auth UID
  /// - role: The new role to assign
  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      // Write profile boolean flags. We also write the legacy `role` string
      // for backward compatibility; this can be removed in a future migration.
      final bool asAdmin = role == UserRole.admin;
      final bool asParent = role == UserRole.parent;

      await _firestore.collection(FirestoreConstants.usersCollection).doc(userId).update({
        'isAdmin': asAdmin,
        'isParent': asParent,
        // NOTE: legacy `role` string is no longer written. Use Firebase Auth
        // custom claims for authorization and `isAdmin`/`isParent` for profile.
        FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate a user account (soft delete)
  /// 
  /// This sets isActive to false instead of deleting the document.
  /// Deactivated users cannot log in but their data is preserved.
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
  @override
  Future<void> deactivateUser(String userId) async {
    try {
      await _firestore.collection(FirestoreConstants.usersCollection).doc(userId).update({
        FirestoreConstants.isActive: false,
        FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Activate a user account
  /// 
  /// This sets isActive to true, allowing the user to log in again.
  /// 
  /// Parameters:
  /// - userId: The Firebase Auth UID
  @override
  Future<void> activateUser(String userId) async {
    try {
      await _firestore.collection(FirestoreConstants.usersCollection).doc(userId).update({
        FirestoreConstants.isActive: true,
        FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
      });
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
    Query query = _firestore.collection(FirestoreConstants.usersCollection).where(
      role == UserRole.admin ? 'isAdmin' : 'isParent',
      isEqualTo: true,
    );

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  /// Get all active users
  /// 
  /// Returns: Stream of all active AppUser objects
  Stream<List<AppUser>> getAllActiveUsers() {
    return _firestore
        .collection(FirestoreConstants.usersCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Get all users (interface implementation)
  @override
  Stream<List<AppUser>> getAllUsers() {
    return _firestore
        .collection(FirestoreConstants.usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .toList());
  }

  /// Search users by email (interface implementation)
  @override
  Stream<List<AppUser>> searchUsersByEmail(String query) {
    return _firestore
        .collection(FirestoreConstants.usersCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .where((user) => user.email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
}

