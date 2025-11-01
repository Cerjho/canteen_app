import 'package:flutter/foundation.dart';

/// Top-up Status
enum TopupStatus {
  pending,
  approved,
  declined,
  completed;

  String get displayName {
    switch (this) {
      case TopupStatus.pending:
        return 'Pending';
      case TopupStatus.approved:
        return 'Approved';
      case TopupStatus.declined:
        return 'Declined';
      case TopupStatus.completed:
        return 'Completed';
    }
  }
}

/// Payment Method
enum PaymentMethod {
  cash,
  card,
  bankTransfer,
  online;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.online:
        return 'Online Payment';
    }
  }
}

/// Top-up model - represents a balance top-up request
@immutable
class Topup {
  final String id;
  final String parentId;
  final String parentName;
  final String? studentId;
  final String? studentName;
  final double amount;
  final TopupStatus status;
  final PaymentMethod paymentMethod;
  final String? transactionReference;
  final String? proofImageUrl;
  final String? notes;
  final String? adminNotes;
  final String? processedBy; // Admin ID who processed the request
  final DateTime requestDate;
  final DateTime? processedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Topup({
    required this.id,
    required this.parentId,
    required this.parentName,
    this.studentId,
    this.studentName,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    this.transactionReference,
    this.proofImageUrl,
    this.notes,
    this.adminNotes,
    this.processedBy,
    required this.requestDate,
    this.processedAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to database document
  /// Uses snake_case for Postgres compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'parent_name': parentName,
      'student_id': studentId,
      'student_name': studentName,
      'amount': amount,
      'status': status.name,
      'payment_method': paymentMethod.name,
      'transaction_reference': transactionReference,
      'proof_image_url': proofImageUrl,
      'notes': notes,
      'admin_notes': adminNotes,
      'processed_by': processedBy,
      'request_date': requestDate.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create from database document
  /// Supports both snake_case (Postgres) and camelCase (legacy) field names
  factory Topup.fromMap(Map<String, dynamic> map) {
    return Topup(
      id: map['id'] as String,
      parentId: (map['parent_id'] ?? map['parentId']) as String,
      parentName: (map['parent_name'] ?? map['parentName']) as String,
      studentId: (map['student_id'] ?? map['studentId']) as String?,
      studentName: (map['student_name'] ?? map['studentName']) as String?,
      amount: (map['amount'] as num).toDouble(),
      status: TopupStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TopupStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == (map['payment_method'] ?? map['paymentMethod']),
        orElse: () => PaymentMethod.cash,
      ),
      transactionReference: (map['transaction_reference'] ?? map['transactionReference']) as String?,
      proofImageUrl: (map['proof_image_url'] ?? map['proofImageUrl']) as String?,
      notes: map['notes'] as String?,
      adminNotes: (map['admin_notes'] ?? map['adminNotes']) as String?,
      processedBy: (map['processed_by'] ?? map['processedBy']) as String?,
      requestDate: DateTime.parse((map['request_date'] ?? map['requestDate']) as String),
      processedAt: (map['processed_at'] ?? map['processedAt']) != null
          ? DateTime.parse((map['processed_at'] ?? map['processedAt']) as String)
          : null,
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      updatedAt: (map['updated_at'] ?? map['updatedAt']) != null
          ? DateTime.parse((map['updated_at'] ?? map['updatedAt']) as String)
          : null,
    );
  }

  /// Create a copy with modified fields
  Topup copyWith({
    String? id,
    String? parentId,
    String? parentName,
    String? studentId,
    String? studentName,
    double? amount,
    TopupStatus? status,
    PaymentMethod? paymentMethod,
    String? transactionReference,
    String? proofImageUrl,
    String? notes,
    String? adminNotes,
    String? processedBy,
    DateTime? requestDate,
    DateTime? processedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Topup(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      notes: notes ?? this.notes,
      adminNotes: adminNotes ?? this.adminNotes,
      processedBy: processedBy ?? this.processedBy,
      requestDate: requestDate ?? this.requestDate,
      processedAt: processedAt ?? this.processedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
