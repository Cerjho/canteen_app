/// Parent Transaction Model
///
/// Represents a transaction record for a parent's wallet balance changes.
/// Used for tracking top-ups, order deductions, and balance adjustments.
class ParentTransaction {
  final String id;
  final String parentId;
  final double amount; // Positive for top-ups, negative for deductions
  final double? balanceBefore;
  final double? balanceAfter;
  final List<String> orderIds;
  final String reason; // 'topup', 'weekly_order', 'single_order', 'weekly_order_deferred', etc.
  final DateTime createdAt;

  const ParentTransaction({
    required this.id,
    required this.parentId,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    required this.orderIds,
    required this.reason,
    required this.createdAt,
  });

  /// Create ParentTransaction from Supabase map
  factory ParentTransaction.fromMap(Map<String, dynamic> map) {
    return ParentTransaction(
      id: map['id'] as String? ?? '',
      parentId: map['parent_id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (map['balance_before'] as num?)?.toDouble(),
      balanceAfter: (map['balance_after'] as num?)?.toDouble(),
      orderIds: (map['order_ids'] as List?)?.cast<String>()
              ?? (map['reference_id'] != null ? <String>[map['reference_id'] as String] : <String>[]),
      reason: (map['reason'] as String?)
              ?? (map['description'] as String?)
              ?? ((map['type'] as String?) == 'debit' ? 'single_order' : (map['type'] as String? ?? '')),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert ParentTransaction to Supabase map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'order_ids': orderIds,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with method for creating modified copies
  ParentTransaction copyWith({
    String? id,
    String? parentId,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    List<String>? orderIds,
    String? reason,
    DateTime? createdAt,
  }) {
    return ParentTransaction(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      orderIds: orderIds ?? this.orderIds,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ParentTransaction(id: $id, parentId: $parentId, amount: $amount, reason: $reason, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParentTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
