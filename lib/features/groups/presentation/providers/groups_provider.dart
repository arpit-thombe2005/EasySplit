import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/connectivity_service.dart';
import 'package:easy_split/core/services/local_cache_service.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/groups/data/repositories/groups_repository_impl.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/features/groups/domain/repositories/groups_repository.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';

// ── Repository Provider ───────────────────────────────────────────

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepositoryImpl(api: ref.watch(apiServiceProvider));
});

// ── Groups List ───────────────────────────────────────────────────

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    final isOffline = ref.watch(isOfflineProvider);
    final cache = ref.watch(localCacheServiceProvider);

    if (isOffline) {
      return cache.getCachedGroups();
    }

    try {
      final groups = await ref.read(groupsRepositoryProvider).getMyGroups();
      await cache.saveGroups(groups);
      return groups;
    } catch (e) {
      final cached = await cache.getCachedGroups();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Group?> createGroup({required String name, String? description}) async {
    try {
      final group = await ref.read(groupsRepositoryProvider).createGroup(
            name: name,
            description: description,
          );
      final current = state.valueOrNull ?? [];
      final updated = [group, ...current];
      state = AsyncData(updated);

      final cache = ref.read(localCacheServiceProvider);
      await cache.saveGroups(updated);
      await cache.saveGroupDetail(group);
      return group;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    await ref.read(groupsRepositoryProvider).deleteGroup(groupId);
    final current = state.valueOrNull ?? [];
    final updated = current.where((g) => g.id != groupId).toList();
    state = AsyncData(updated);

    final cache = ref.read(localCacheServiceProvider);
    await cache.saveGroups(updated);
  }

  Future<void> leaveGroup(String groupId) async {
    await ref.read(groupsRepositoryProvider).leaveGroup(groupId);
    final current = state.valueOrNull ?? [];
    final updated = current.where((g) => g.id != groupId).toList();
    state = AsyncData(updated);

    final cache = ref.read(localCacheServiceProvider);
    await cache.saveGroups(updated);
  }

  Future<void> toggleGroupLock(String groupId, bool isLocked) async {
    final updatedGroup = await ref.read(groupsRepositoryProvider).toggleGroupLock(groupId: groupId, isLocked: isLocked);
    final current = state.valueOrNull ?? [];
    final updatedList = current.map((g) => g.id == groupId ? updatedGroup : g).toList();
    state = AsyncData(updatedList);

    final cache = ref.read(localCacheServiceProvider);
    await cache.saveGroups(updatedList);
    await cache.saveGroupDetail(updatedGroup);

    ref.invalidate(groupDetailProvider(groupId));
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, List<Group>>(GroupsNotifier.new);

// ── Single Group & Analytics ──────────────────────────────────────

final groupDetailProvider =
    FutureProvider.family<Group, String>((ref, groupId) async {
  final isOffline = ref.watch(isOfflineProvider);
  final cache = ref.watch(localCacheServiceProvider);

  if (isOffline) {
    final cached = await cache.getCachedGroupDetail(groupId);
    if (cached != null) return cached;
    final groups = await cache.getCachedGroups();
    final found = groups.where((g) => g.id == groupId).firstOrNull;
    if (found != null) return found;
  }

  try {
    final group = await ref.read(groupsRepositoryProvider).getGroup(groupId);
    await cache.saveGroupDetail(group);
    return group;
  } catch (e) {
    final cached = await cache.getCachedGroupDetail(groupId);
    if (cached != null) return cached;
    final groups = await cache.getCachedGroups();
    final found = groups.where((g) => g.id == groupId).firstOrNull;
    if (found != null) return found;
    rethrow;
  }
});

final groupAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, ({String groupId, String? filter, String? startDate, String? endDate})>((ref, arg) async {
  return ref.read(groupsRepositoryProvider).getAnalytics(
        groupId: arg.groupId,
        filter: arg.filter,
        startDate: arg.startDate,
        endDate: arg.endDate,
      );
});

// ── Group Form State ──────────────────────────────────────────────

class GroupFormState {
  final bool isLoading;
  final String? error;

  const GroupFormState({this.isLoading = false, this.error});

  GroupFormState copyWith({bool? isLoading, String? error, bool clearError = false}) =>
      GroupFormState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class GroupFormNotifier extends Notifier<GroupFormState> {
  @override
  GroupFormState build() => const GroupFormState();

  Future<Group?> createGroup({required String name, String? description}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final group = await ref
          .read(groupsNotifierProvider.notifier)
          .createGroup(name: name, description: description);
      state = const GroupFormState();
      return group;
    } catch (e) {
      state = GroupFormState(
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> addMember({required String groupId, required String email}) async {
    final trimmed = email.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (trimmed.isEmpty || !emailRegex.hasMatch(trimmed)) {
      state = const GroupFormState(error: 'Please enter a valid email address');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(invitationsRepositoryProvider).sendInvitation(
            groupId: groupId,
            email: trimmed,
          );
      state = const GroupFormState();
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupInvitationsProvider(groupId));
      return true;
    } catch (e) {
      state = GroupFormState(error: e.toString());
      return false;
    }
  }

  Future<bool> resendInvitation({required String groupId, required String invitationId}) async {
    try {
      await ref.read(invitationsRepositoryProvider).resendInvitation(
            groupId: groupId,
            invitationId: invitationId,
          );
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupInvitationsProvider(groupId));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelInvitation({required String groupId, required String invitationId}) async {
    try {
      await ref.read(invitationsRepositoryProvider).cancelInvitation(
            groupId: groupId,
            invitationId: invitationId,
          );
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupInvitationsProvider(groupId));
      return true;
    } catch (e) {
      return false;
    }
  }
}

final groupFormProvider =
    NotifierProvider<GroupFormNotifier, GroupFormState>(GroupFormNotifier.new);
