import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/features/groups/domain/repositories/groups_repository.dart';

/// Concrete implementation of [GroupsRepository].
class GroupsRepositoryImpl implements GroupsRepository {
  final ApiService _api;

  GroupsRepositoryImpl({required ApiService api}) : _api = api;

  @override
  Future<List<Group>> getMyGroups() async {
    final data = await _api.get('/groups');
    final list = data['groups'] as List<dynamic>;
    return list.map((g) => Group.fromJson(g as Map<String, dynamic>)).toList();
  }

  @override
  Future<Group> getGroup(String groupId) async {
    final data = await _api.get('/groups/$groupId');
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  @override
  Future<Group> createGroup({required String name, String? description}) async {
    final data = await _api.post('/groups', data: {
      'name': name,
      if (description != null) 'description': description,
    });
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  @override
  Future<Group> updateGroup({
    required String groupId,
    String? name,
    String? description,
  }) async {
    final data = await _api.put('/groups/$groupId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _api.delete('/groups/$groupId');
  }

  @override
  Future<GroupMember> addMember({
    required String groupId,
    required String email,
  }) async {
    final data = await _api.post('/groups/$groupId/members', data: {
      'email': email.toLowerCase().trim(),
    });
    return GroupMember.fromJson(data['member'] as Map<String, dynamic>);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _api.delete('/groups/$groupId/members/$userId');
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await _api.post('/groups/$groupId/leave');
  }

  @override
  Future<List<int>> exportExpenses(String groupId) async {
    return _api.getBytes('/groups/$groupId/export');
  }

  @override
  Future<List<int>> exportPdf(String groupId) async {
    return _api.getBytes('/groups/$groupId/export-pdf');
  }

  @override
  Future<Group> toggleGroupLock({required String groupId, required bool isLocked}) async {
    final data = await _api.patch('/groups/$groupId/lock', data: {
      'isLocked': isLocked,
    });
    return Group.fromJson(data['group'] as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getAnalytics({
    required String groupId,
    String? filter,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (filter != null) query['filter'] = filter;
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;

    final data = await _api.get('/groups/$groupId/analytics', queryParameters: query);
    return data['analytics'] as Map<String, dynamic>;
  }
}
