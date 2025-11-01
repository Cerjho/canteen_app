import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Parent model - represents a parent/guardian in the canteen system
/// 
/// This model stores parent-specific information separate from the base user account.
/// Each parent has a corresponding document in the `users` collection with basic info.
/// 
/// Firestore Structure:
/// ```
/// parents/{uid}/  (uid matches the Firebase Auth UID and users collection doc ID)
///   ├── userId: string (reference to users collection, same as doc ID)
///   ├── balance: number (parent's account balance for purchases)
///   ├── address: string (optional, parent's address)
///   ├── phone: string (parent's phone number)
///   ├── children: array<string> (array of student IDs linked to this parent)
///   ├── photoUrl: string (optional, profile photo)
///   ├── isActive: boolean
///   ├── createdAt: timestamp
///   └── updatedAt: timestamp (nullable)
/// ```
@immutable
class Parent {
  /// User ID - references the document in the `users` collection
  /// This is the same as the Firebase Auth UID
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

  /// Convert to Firestore document format
  /// Matches the required structure: userId, balance, address, phone, children[]
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'address': address,
      'phone': phone,
      'children': children,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory Parent.fromMap(Map<String, dynamic> map) {
    return Parent(
      userId: map['userId'] as String,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      children: List<String>.from(map['children'] ?? []),
      photoUrl: map['photoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
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
