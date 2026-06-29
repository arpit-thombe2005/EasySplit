import 'package:easy_split/features/groups/domain/models/group.dart';

/// Abstract repository interface for group operations.
abstract class GroupsRepository {
  /// Fetch all groups the current user belongs to.
  Future<List<Group>> getMyGroups();

  /// Fetch a single group by ID (with members).
  Future<Group> getGroup(String groupId);

  /// Create a new group.
  Future<Group> createGroup({required String name, String? description});

  /// Update group details.
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? description,
  });

  /// Delete a group (admin only).
  Future<void> deleteGroup(String groupId);

  /// Add a member to a group by email.
  Future<GroupMember> addMember({
    required String groupId,
    required String email,
  });

  /// Remove a member from a group.
  Future<void> removeMember({
    required String groupId,
    required String userId,
  });

  /// Leave a group (current user removes themselves).
  Future<void> leaveGroup(String groupId);
}
