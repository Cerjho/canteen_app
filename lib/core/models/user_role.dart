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

  /// Convert to string for storage
  String toJson() => name;

  /// Parse from string
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
/// This is stored in the `users` table and contains basic account information
/// for ALL users regardless of role. Additional role-specific data is stored in
/// separate tables (e.g., `parents` table for parent-specific data).
/// 
/// Database Structure:
/// ```
/// users/
///   ├── id: uuid (Supabase Auth UUID)
///   ├── first_name: text (first name)
///   ├── last_name: text (last name)
///   ├── email: text (email address)
///   ├── is_admin: boolean
///   ├── is_parent: boolean
///   ├── created_at: timestamptz
///   ├── updated_at: timestamptz (nullable)
///   └── is_active: boolean
/// ```
class AppUser {
  /// Supabase Auth UUID - used as primary key
  final String uid;
  
  /// User's first name
  final String firstName;
  
  /// User's last name
  final String lastName;
  
  /// User's email address (synced with Supabase Auth)
  final String email;
  
  /// Profile booleans stored in the user record.
  /// These are used for profile information and role-based access.
  final bool isAdmin;
  final bool isParent;
  
  /// When the account was created
  final DateTime createdAt;
  
  /// When the account was last updated (nullable)
  final DateTime? updatedAt;
  
  /// Whether the account is active (for soft deletion)
  final bool isActive;

  /// Whether the user still needs to complete onboarding
  /// Parent flow uses this to redirect to /complete-registration
  final bool needsOnboarding;

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
    this.needsOnboarding = false,
  });

  /// Computed full name getter for backward compatibility
  String get name => '$firstName $lastName'.trim();

  /// Check if user is admin (profile flag)
  bool get isAdminFlag => isAdmin;

  /// Check if user is parent (profile flag)
  bool get isParentFlag => isParent;

  /// Convert to database format
  /// Maps to snake_case column names in Postgres
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'is_admin': isAdmin,
      'is_parent': isParent,
      'is_active': isActive,
      'needs_onboarding': needsOnboarding,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database record
  /// Supports backward compatibility with legacy camelCase field names
  factory AppUser.fromMap(Map<String, dynamic> map) {
    // Handle both snake_case (new) and camelCase (legacy) field names
    String firstName;
    String lastName;
    
    if (map.containsKey('first_name') && map.containsKey('last_name')) {
      firstName = map['first_name'] as String;
      lastName = map['last_name'] as String;
    } else if (map.containsKey('firstName') && map.containsKey('lastName')) {
      // Legacy camelCase support
      firstName = map['firstName'] as String;
      lastName = map['lastName'] as String;
    } else if (map.containsKey('name')) {
      // Legacy support: split 'name' into firstName/lastName
      final nameParts = (map['name'] as String).split(' ');
      firstName = nameParts.first;
      lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    } else {
      throw Exception('User document must have either first_name/last_name or name field');
    }
    
    // Handle both snake_case (new) and camelCase (legacy) for boolean flags
    final bool parsedIsAdmin;
    final bool parsedIsParent;

    if (map.containsKey('is_admin') || map.containsKey('is_parent')) {
      // New snake_case format
      parsedIsAdmin = map['is_admin'] as bool? ?? false;
      parsedIsParent = map['is_parent'] as bool? ?? false;
    } else if (map.containsKey('isAdmin') || map.containsKey('isParent')) {
      // Legacy camelCase format
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

    // Parse timestamps - handle both ISO strings and DateTime objects
    DateTime parseDateTime(dynamic value, DateTime defaultValue) {
      if (value == null) return defaultValue;
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return defaultValue;
    }

    // Handle both snake_case (new) and camelCase (legacy) for other fields
    final uid = (map['id'] ?? map['uid']) as String;
    final email = map['email'] as String;
    final isActive = (map['is_active'] ?? map['isActive']) as bool? ?? true;
  final needsOnboarding = (map['needs_onboarding'] ?? map['needsOnboarding']) as bool? ?? false;
    final createdAt = parseDateTime(
      map['created_at'] ?? map['createdAt'],
      DateTime.now(),
    );
    final updatedAt = parseDateTime(
      map['updated_at'] ?? map['updatedAt'],
      DateTime.now(),
    );

    return AppUser(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      isAdmin: parsedIsAdmin,
      isParent: parsedIsParent,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: map.containsKey('updated_at') || map.containsKey('updatedAt') 
          ? updatedAt 
          : null,
      needsOnboarding: needsOnboarding,
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
    bool? needsOnboarding,
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
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
    );
  }
}
