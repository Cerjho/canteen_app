import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentId': parentId,
      'parentName': parentName,
      'studentId': studentId,
      'studentName': studentName,
      'amount': amount,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'transactionReference': transactionReference,
      'proofImageUrl': proofImageUrl,
      'notes': notes,
      'adminNotes': adminNotes,
      'processedBy': processedBy,
      'requestDate': Timestamp.fromDate(requestDate),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory Topup.fromMap(Map<String, dynamic> map) {
    return Topup(
      id: map['id'] as String,
      parentId: map['parentId'] as String,
      parentName: map['parentName'] as String,
      studentId: map['studentId'] as String?,
      studentName: map['studentName'] as String?,
      amount: (map['amount'] as num).toDouble(),
      status: TopupStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TopupStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      transactionReference: map['transactionReference'] as String?,
      proofImageUrl: map['proofImageUrl'] as String?,
      notes: map['notes'] as String?,
      adminNotes: map['adminNotes'] as String?,
      processedBy: map['processedBy'] as String?,
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
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
