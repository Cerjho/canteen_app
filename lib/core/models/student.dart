import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Convert to Firestore document format
  /// Matches the required structure: id, parentId, name, gradeLevel, balance
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'grade': grade,
      'parentId': parentId,
      'allergies': allergies,
      'dietaryRestrictions': dietaryRestrictions,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      grade: map['grade'] as String,
      parentId: map['parentId'] as String?,
      allergies: map['allergies'] as String?,
      dietaryRestrictions: map['dietaryRestrictions'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
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
