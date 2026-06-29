import 'package:easy_split/features/groups/domain/models/invitation.dart';

/// Abstract repository interface for group invitation operations.
abstract class InvitationsRepository {
  /// Send an invitation to join a group by email.
  Future<GroupInvitation> sendInvitation({
    required String groupId,
    required String email,
  });

  /// Fetch all pending invitations for the current logged-in user.
  Future<List<GroupInvitation>> getPendingInvitations();

  /// Accept a group invitation.
  Future<void> acceptInvitation(String invitationId);

  /// Decline a group invitation.
  Future<void> declineInvitation(String invitationId);

  /// Fetch all invitations for a specific group (for sender/members to see status).
  Future<List<GroupInvitation>> getGroupInvitations(String groupId);

  /// Resend a declined invitation for a group.
  Future<void> resendInvitation({
    required String groupId,
    required String invitationId,
  });

  /// Cancel a pending invitation for a group.
  Future<void> cancelInvitation({
    required String groupId,
    required String invitationId,
  });
}
