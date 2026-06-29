import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/features/groups/domain/models/invitation.dart';
import 'package:easy_split/features/groups/domain/repositories/invitations_repository.dart';

/// Concrete implementation of [InvitationsRepository].
class InvitationsRepositoryImpl implements InvitationsRepository {
  final ApiService _api;

  InvitationsRepositoryImpl({required ApiService api}) : _api = api;

  @override
  Future<GroupInvitation> sendInvitation({
    required String groupId,
    required String email,
  }) async {
    final data = await _api.post('/groups/$groupId/invitations', data: {
      'email': email.toLowerCase().trim(),
    });
    return GroupInvitation.fromJson(data['invitation'] as Map<String, dynamic>);
  }

  @override
  Future<List<GroupInvitation>> getPendingInvitations() async {
    final data = await _api.get('/invitations/pending');
    final list = data['invitations'] as List<dynamic>;
    return list.map((i) => GroupInvitation.fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await _api.post('/invitations/$invitationId/accept');
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _api.post('/invitations/$invitationId/decline');
  }

  @override
  Future<List<GroupInvitation>> getGroupInvitations(String groupId) async {
    final data = await _api.get('/groups/$groupId/invitations');
    final list = data['invitations'] as List<dynamic>;
    return list.map((i) => GroupInvitation.fromJson(i as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> resendInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    await _api.post('/groups/$groupId/invitations/$invitationId/resend');
  }

  @override
  Future<void> cancelInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    await _api.delete('/groups/$groupId/invitations/$invitationId');
  }
}
