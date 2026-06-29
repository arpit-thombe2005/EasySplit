/// Domain model for a debt Settlement.
class Settlement {
  final String id;
  final String fromUser;
  final String toUser;
  final String? groupId;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String status; // 'pending', 'completed', 'rejected'
  final DateTime? settledAt;
  final DateTime? createdAt;
  // Enriched fields
  final String? fromUserName;
  final String? toUserName;
  final String? fromUserAvatar;
  final String? toUserAvatar;

  const Settlement({
    required this.id,
    required this.fromUser,
    required this.toUser,
    this.groupId,
    required this.amount,
    this.paymentMethod = 'UPI',
    this.note,
    this.status = 'pending',
    this.settledAt,
    this.createdAt,
    this.fromUserName,
    this.toUserName,
    this.fromUserAvatar,
    this.toUserAvatar,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      fromUser: (json['fromUser'] ?? json['from_user']) as String,
      toUser: (json['toUser'] ?? json['to_user']) as String,
      groupId: (json['groupId'] ?? json['group_id']) as String?,
      amount: double.parse((json['amount'] ?? 0).toString()),
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'UPI') as String,
      note: json['note'] as String?,
      status: (json['status'] ?? 'pending') as String,
      settledAt: json['settledAt'] != null
          ? DateTime.tryParse(json['settledAt'].toString())
          : (json['settled_at'] != null ? DateTime.tryParse(json['settled_at'].toString()) : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
      fromUserName: (json['fromUserName'] ?? json['from_user_name']) as String?,
      toUserName: (json['toUserName'] ?? json['to_user_name']) as String?,
      fromUserAvatar: (json['fromUserAvatar'] ?? json['from_user_avatar']) as String?,
      toUserAvatar: (json['toUserAvatar'] ?? json['to_user_avatar']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUser': fromUser,
      'toUser': toUser,
      'groupId': groupId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'note': note,
      'status': status,
      'settledAt': settledAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'fromUserName': fromUserName,
      'toUserName': toUserName,
      'fromUserAvatar': fromUserAvatar,
      'toUserAvatar': toUserAvatar,
    };
  }
}

/// Model for simplified debt instructions (who owes whom)
class SimplifiedDebt {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;

  const SimplifiedDebt({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });
}
