import 'package:flutter/foundation.dart';

/// Parent model - represents a parent/guardian in the canteen system
/// 
/// This model stores parent-specific information separate from the base user account.
/// Each parent has a corresponding document in the `users` collection with basic info.
/// 
/// Supabase Structure:
/// ```
/// parents/{user_id}/  (user_id matches the Supabase Auth UUID and users table uid)
///   ├── user_id: UUID (reference to users table, same as Supabase Auth UUID)
///   ├── balance: decimal (parent's account balance for purchases)
///   ├── address: text (optional, parent's address)
///   ├── phone: text (parent's phone number)
///   ├── student_ids: text[] (array of student UUIDs linked to this parent)
///   ├── created_at: timestamptz
///   └── updated_at: timestamptz (nullable)
/// ```
@immutable
class Parent {
  /// User ID - references the users table
  /// This is the same as the Supabase Auth UUID
  final String userId;
  
  /// Parent's account balance for making purchases
  final double balance;
  
  /// Parent's physical address (optional)
  final String? address;
  
  /// Parent's phone number for contact (optional)
  final String? phone;
  
  /// Array of student IDs (references to documents in `students` collection)
  /// These are the children linked to this parent
  final List<String> children;
  
  /// Optional profile photo URL
  final String? photoUrl;
  
  /// Whether the parent account is active
  final bool isActive;
  
  /// When the parent record was created
  final DateTime createdAt;
  
  /// When the parent record was last updated
  final DateTime? updatedAt;

  const Parent({
    required this.userId,
    this.balance = 0.0,
    this.address,
    this.phone,
    this.children = const [],
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to database document format
  /// Matches the required structure: userId, balance, address, phone, student_ids[]
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'balance': balance,
      'address': address,
      'phone': phone,
      'student_ids': children, // Database uses student_ids
      'photo_url': photoUrl,
      // Note: parents table does not have is_active column in current schema
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory Parent.fromMap(Map<String, dynamic> map) {
    return Parent(
      userId: (map['user_id'] ?? map['userId']) as String,
      balance: ((map['balance'] as num?)?.toDouble()) ?? 0.0,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      children: List<String>.from(map['student_ids'] ?? map['children'] ?? []), // Database uses student_ids
      photoUrl: (map['photo_url'] ?? map['photoUrl']) as String?,
      isActive: (map['is_active'] ?? map['isActive']) as bool? ?? true,
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  Parent copyWith({
    String? userId,
    double? balance,
    String? address,
    String? phone,
    List<String>? children,
    String? photoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Parent(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      children: children ?? this.children,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
