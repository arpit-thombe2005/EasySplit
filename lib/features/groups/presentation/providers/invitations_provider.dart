import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/groups/data/repositories/invitations_repository_impl.dart';
import 'package:easy_split/features/groups/domain/models/invitation.dart';
import 'package:easy_split/features/groups/domain/repositories/invitations_repository.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';

// ── Repository Provider ───────────────────────────────────────────

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  return InvitationsRepositoryImpl(api: ref.watch(apiServiceProvider));
});

// ── Pending Invitations Notifier ──────────────────────────────────

class PendingInvitationsNotifier extends AsyncNotifier<List<GroupInvitation>> {
  @override
  Future<List<GroupInvitation>> build() async {
    return ref.read(invitationsRepositoryProvider).getPendingInvitations();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<bool> acceptInvitation(String invitationId) async {
    try {
      final currentList = state.valueOrNull ?? [];
      final match = currentList.firstWhere((i) => i.id == invitationId, orElse: () => GroupInvitation(id: invitationId, groupId: '', groupName: ''));

      await ref.read(invitationsRepositoryProvider).acceptInvitation(invitationId);
      state = AsyncData(currentList.where((i) => i.id != invitationId).toList());
      
      ref.invalidate(groupsNotifierProvider);
      if (match.groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(match.groupId));
        ref.invalidate(groupInvitationsProvider(match.groupId));
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> declineInvitation(String invitationId) async {
    try {
      final currentList = state.valueOrNull ?? [];
      final match = currentList.firstWhere((i) => i.id == invitationId, orElse: () => GroupInvitation(id: invitationId, groupId: '', groupName: ''));

      await ref.read(invitationsRepositoryProvider).declineInvitation(invitationId);
      state = AsyncData(currentList.where((i) => i.id != invitationId).toList());
      
      if (match.groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(match.groupId));
        ref.invalidate(groupInvitationsProvider(match.groupId));
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }
}

final pendingInvitationsProvider =
    AsyncNotifierProvider<PendingInvitationsNotifier, List<GroupInvitation>>(
  PendingInvitationsNotifier.new,
);

// ── Group Specific Invitations Provider ───────────────────────────

final groupInvitationsProvider =
    FutureProvider.family<List<GroupInvitation>, String>((ref, groupId) async {
  return ref.read(invitationsRepositoryProvider).getGroupInvitations(groupId);
});
