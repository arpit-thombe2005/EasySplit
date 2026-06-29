/// Domain model for a Group Invitation.
class GroupInvitation {
  final String id;
  final String groupId;
  final String? groupName;
  final String senderId;
  final String? senderName;
  final String? senderAvatarId;
  final String receiverId;
  final String? receiverName;
  final String? receiverEmail;
  final String? receiverAvatarId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GroupInvitation({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.senderId,
    this.senderName,
    this.senderAvatarId,
    required this.receiverId,
    this.receiverName,
    this.receiverEmail,
    this.receiverAvatarId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: (json['groupId'] ?? json['group_id']) as String,
      groupName: (json['groupName'] ?? json['group_name']) as String?,
      senderId: (json['senderId'] ?? json['sender_id']) as String,
      senderName: (json['senderName'] ?? json['sender_name']) as String?,
      senderAvatarId: (json['senderAvatarId'] ?? json['sender_avatar_id']) as String?,
      receiverId: (json['receiverId'] ?? json['receiver_id']) as String,
      receiverName: (json['receiverName'] ?? json['receiver_name']) as String?,
      receiverEmail: (json['receiverEmail'] ?? json['receiver_email']) as String?,
      receiverAvatarId: (json['receiverAvatarId'] ?? json['receiver_avatar_id']) as String?,
      status: json['status'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarId': senderAvatarId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverEmail': receiverEmail,
      'receiverAvatarId': receiverAvatarId,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
