import 'package:cloud_firestore/cloud_firestore.dart';

/// User role enum
/// Supports two primary roles: admin and parent
/// Designed for future extensibility (e.g., cashier, teacher, etc.)
enum UserRole {
  admin,
  parent;
  // Future roles can be added here:
  // cashier,
  // teacher,
  // etc.

  /// Convert to string for storage in Firestore (legacy support)
  String toJson() => name;

  /// Parse from string stored in Firestore
  /// Returns parent as default for unknown roles (safe fallback)
  static UserRole fromJson(String json) {
    return UserRole.values.firstWhere(
      (role) => role.name == json,
      orElse: () => UserRole.parent, // Default to parent if unknown
    );
  }
}

/// App User model - represents a user account in the canteen system
/// 
/// This is stored in the `users` collection and contains basic account information
/// for ALL users regardless of role. Additional role-specific data is stored in
/// separate collections (e.g., `parents` collection for parent-specific data).
/// 
/// Firestore Structure:
/// ```
/// users/{uid}/
///   ├── uid: string (Firebase Auth UID)
///   ├── firstName: string (first name)
///   ├── lastName: string (last name)
///   ├── email: string (email address)
///   ├── role: string ("admin" | "parent")
///   ├── createdAt: timestamp
///   ├── updatedAt: timestamp (nullable)
///   └── isActive: boolean
/// ```
class AppUser {
  /// Firebase Auth UID - used as document ID in Firestore
  final String uid;
  
  /// User's first name
  final String firstName;
  
  /// User's last name
  final String lastName;
  
  /// User's email address (synced with Firebase Auth)
  final String email;
  
  /// Profile booleans stored in the user document.
  /// These are used for profile information only (UI / profile pages).
  /// Role-based access should be determined from Firebase Auth custom claims.
  final bool isAdmin;
  final bool isParent;
  
  /// When the account was created
  final DateTime createdAt;
  
  /// When the account was last updated (nullable)
  final DateTime? updatedAt;
  
  /// Whether the account is active (for soft deletion)
  final bool isActive;

  AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
  required this.isAdmin,
  required this.isParent,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  /// Computed full name getter for backward compatibility
  String get name => '$firstName $lastName'.trim();

  /// Check if user is admin (profile flag)
  bool get isAdminFlag => isAdmin;

  /// Check if user is parent (profile flag)
  bool get isParentFlag => isParent;

  /// Convert to Firestore document format
  /// This matches the required structure: uid, firstName, lastName, email, role, createdAt, isActive
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      // Persist profile flags. We intentionally write booleans for profile
      // so clients can show/hide profile UI without relying on auth token.
      'isAdmin': isAdmin,
      'isParent': isParent,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  /// Supports backward compatibility with legacy 'name' field
  factory AppUser.fromMap(Map<String, dynamic> map) {
    // Handle legacy data with 'name' field
    String firstName;
    String lastName;
    
    if (map.containsKey('firstName') && map.containsKey('lastName')) {
      firstName = map['firstName'] as String;
      lastName = map['lastName'] as String;
    } else if (map.containsKey('name')) {
      // Legacy support: split 'name' into firstName/lastName
      final nameParts = (map['name'] as String).split(' ');
      firstName = nameParts.first;
      lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    } else {
      throw Exception('User document must have either firstName/lastName or name field');
    }
    
    // Legacy compatibility: support both new boolean flags (`isAdmin`/`isParent`)
    // and the legacy `role` string. Preference is given to explicit booleans.
    final bool parsedIsAdmin;
    final bool parsedIsParent;

    if (map.containsKey('isAdmin') || map.containsKey('isParent')) {
      parsedIsAdmin = map['isAdmin'] as bool? ?? false;
      parsedIsParent = map['isParent'] as bool? ?? false;
    } else if (map.containsKey('role')) {
      // Legacy single string role
      final legacyRole = (map['role'] as String?) ?? 'parent';
      final parsedRole = UserRole.fromJson(legacyRole);
      parsedIsAdmin = parsedRole == UserRole.admin;
      parsedIsParent = parsedRole == UserRole.parent;
    } else {
      // Safe default: treat as parent to avoid locking users out
      parsedIsAdmin = false;
      parsedIsParent = true;
    }

    return AppUser(
      uid: map['uid'] as String,
      firstName: firstName,
      lastName: lastName,
      email: map['email'] as String,
      isAdmin: parsedIsAdmin,
      isParent: parsedIsParent,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Create a copy with updated fields
  AppUser copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    bool? isAdmin,
    bool? isParent,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      isParent: isParent ?? this.isParent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
