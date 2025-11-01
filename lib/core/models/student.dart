import 'package:flutter/foundation.dart';

/// Student model - represents a student in the canteen system
/// 
/// Students are linked to parents through the parentId field.
/// NOTE: Student documents include a `balance` field for administrative
/// or reference purposes only. Orders and runtime billing are charged to
/// the linked parent's wallet (the `parents` collection). The student
/// balance field is kept for reporting, migration, or admin adjustments
/// and should not be relied on by parent-facing order flows.
/// 
/// Firestore Structure:
/// ```
/// students/{id}/
///   ├── id: string (auto-generated or custom ID)
///   ├── parentId: string (reference to parent's userId)
///   ├── firstName: string (student's first name)  
///   ├── lastName: string (student's last name)
///   ├── gradeLevel: string (e.g., "Grade 1", "Grade 7")
///   ├── allergies: string (optional, comma-separated allergies)
///   ├── dietaryRestrictions: string (optional)
///   ├── photoUrl: string (optional, profile photo)
///   ├── isActive: boolean
///   ├── createdAt: timestamp
///   └── updatedAt: timestamp (nullable)
/// ```
@immutable
class Student {
  /// Unique student ID (document ID in Firestore)
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
      'grade': grade,
      'parent_id': parentId,
      'allergies': allergies,
      'dietary_restrictions': dietaryRestrictions,
      'photo_url': photoUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String,
      firstName: (map['first_name'] ?? map['firstName']) as String,
      lastName: (map['last_name'] ?? map['lastName']) as String,
      grade: map['grade'] as String,
      parentId: (map['parent_id'] ?? map['parentId']) as String?,
      allergies: map['allergies'] as String?,
      dietaryRestrictions: (map['dietary_restrictions'] ?? map['dietaryRestrictions']) as String?,
      photoUrl: (map['photo_url'] ?? map['photoUrl']) as String?,
      isActive: (map['is_active'] ?? map['isActive']) as bool? ?? true,
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
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
