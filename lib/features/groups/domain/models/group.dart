import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';

part 'group.freezed.dart';
part 'group.g.dart';

/// Domain model for a Group.
@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    String? description,
    required String createdBy,
    @Default([]) List<GroupMember> members,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Computed fields from API
    @Default(0.0) double totalExpenses,
    @Default(0.0) double myBalance, // positive = owed, negative = owe
    @Default(false) bool isLocked,
    @Default(false) bool isArchived,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}

/// Domain model for a group member.
@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String id,
    required String groupId,
    required String userId,
    UserRef? user,
    DateTime? joinedAt,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);
}
