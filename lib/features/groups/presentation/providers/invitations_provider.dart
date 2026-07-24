import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/connectivity_service.dart';
import 'package:easy_split/core/services/local_cache_service.dart';
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
    final isOffline = ref.watch(isOfflineProvider);
    final cache = ref.watch(localCacheServiceProvider);

    if (isOffline) {
      return cache.getCachedPendingInvitations();
    }

    try {
      final invitations = await ref.read(invitationsRepositoryProvider).getPendingInvitations();
      await cache.savePendingInvitations(invitations);
      return invitations;
    } catch (e) {
      final cached = await cache.getCachedPendingInvitations();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<bool> acceptInvitation(String invitationId) async {
    try {
      final currentList = state.valueOrNull ?? [];
      final match = currentList.cast<GroupInvitation?>().firstWhere((i) => i?.id == invitationId, orElse: () => null);

      await ref.read(invitationsRepositoryProvider).acceptInvitation(invitationId);
      final updated = currentList.where((i) => i.id != invitationId).toList();
      state = AsyncData(updated);

      final cache = ref.read(localCacheServiceProvider);
      await cache.savePendingInvitations(updated);

      ref.invalidate(groupsNotifierProvider);
      if (match != null && match.groupId.isNotEmpty) {
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
      final match = currentList.cast<GroupInvitation?>().firstWhere((i) => i?.id == invitationId, orElse: () => null);

      await ref.read(invitationsRepositoryProvider).declineInvitation(invitationId);
      final updated = currentList.where((i) => i.id != invitationId).toList();
      state = AsyncData(updated);

      final cache = ref.read(localCacheServiceProvider);
      await cache.savePendingInvitations(updated);

      if (match != null && match.groupId.isNotEmpty) {
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
