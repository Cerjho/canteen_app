import 'package:flutter/foundation.dart';

/// Student model - represents a student in the canteen system
/// 
/// Students are linked to parents through the parentId field.
/// NOTE: Student documents do not have a `balance` field. Orders are
/// charged to the linked parent's wallet (the `parents` collection). 
/// 
/// Supabase Structure:
/// ```
/// students/{id}/
///   ├── id: UUID (primary key)
///   ├── parent_user_id: UUID (reference to users table)
///   ├── first_name: text (student's first name)  
///   ├── last_name: text (student's last name)
///   ├── grade_level: text (e.g., "Grade 1", "Grade 7")
///   ├── section: text (optional)
///   ├── photo_url: text (optional, profile photo)
///   ├── allergies: text[] (array of allergens)
///   ├── dietary_restrictions: text[] (array of restrictions)
///   ├── is_active: boolean
///   ├── created_at: timestamptz
///   └── updated_at: timestamptz (nullable)
/// ```
@immutable
class Student {
  /// Unique student ID (UUID in Supabase)
  final String id;
  
  /// Student's first name
  final String firstName;
  
  /// Student's last name
  final String lastName;
  
  /// Grade level (e.g., "Grade 1", "Grade 7", "Year 10")
  final String grade;
  
  /// Reference to the parent's userId (from users/parents collection)
  /// Links the student to their parent/guardian
  final String? parentId;
  
  /// Student's known allergies (comma-separated if multiple)
  final String? allergies;
  
  /// Dietary restrictions (e.g., "Vegetarian", "Halal", "No pork")
  final String? dietaryRestrictions;
  
  /// Optional profile photo URL
  final String? photoUrl;
  
  
  /// Whether the student account is active
  final bool isActive;
  
  /// When the student record was created
  final DateTime createdAt;
  
  /// When the student record was last updated
  final DateTime? updatedAt;

  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.grade,
    this.parentId,
    this.allergies,
    this.dietaryRestrictions,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get full name of student
  String get fullName => '$firstName $lastName';

  /// Convert to database document format
  /// Matches the required structure: id, parentId, name, gradeLevel, balance
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'grade_level': grade, // Database uses grade_level
    // Ensure empty string is not written to UUID column
    'parent_user_id': (parentId != null && parentId!.trim().isNotEmpty) ? parentId : null, // Database uses parent_user_id
      'allergies': allergies != null && allergies!.isNotEmpty 
          ? allergies!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() 
          : null, // Convert comma-separated string to array
      'dietary_restrictions': dietaryRestrictions != null && dietaryRestrictions!.isNotEmpty
          ? dietaryRestrictions!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : null, // Convert comma-separated string to array
      'photo_url': photoUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory Student.fromMap(Map<String, dynamic> map) {
    // Helper to convert array or string to comma-separated string
    String? listToString(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((e) => e.toString()).join(', ');
      }
      return value.toString();
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }
    
    return Student(
      id: map['id'] as String,
      firstName: (map['first_name'] ?? map['firstName']) as String,
      lastName: (map['last_name'] ?? map['lastName']) as String,
      grade: (map['grade_level'] ?? map['grade']) as String, // Support both field names
      parentId: (map['parent_user_id'] ?? map['parent_id'] ?? map['parentId']) as String?, // Support all variants
      allergies: listToString(map['allergies']), // Convert array to comma-separated string
      dietaryRestrictions: listToString(map['dietary_restrictions'] ?? map['dietaryRestrictions']), // Convert array to string
      photoUrl: (map['photo_url'] ?? map['photoUrl']) as String?,
      isActive: (map['is_active'] ?? map['isActive']) as bool? ?? true,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? parseDate(map['updated_at'] ?? map['updatedAt'])
          : null,
    );
  }

  /// Create a copy with modified fields
  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? grade,
    String? parentId,
    String? allergies,
    String? dietaryRestrictions,
    String? photoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      grade: grade ?? this.grade,
      parentId: parentId ?? this.parentId,
      allergies: allergies ?? this.allergies,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
