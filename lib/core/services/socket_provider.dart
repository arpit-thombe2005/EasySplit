import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/socket_service.dart';
import 'package:easy_split/features/auth/presentation/providers/auth_provider.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/groups_provider.dart';
import 'package:easy_split/features/groups/presentation/providers/invitations_provider.dart';
import 'package:easy_split/features/settlements/presentation/providers/settlements_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final realtimeSyncProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final socket = ref.watch(socketServiceProvider);

  if (user != null && user.id.isNotEmpty) {
    socket.connect(user.id);

    // Watch active user's groups to join group socket rooms automatically
    final groups = ref.watch(groupsNotifierProvider).valueOrNull ?? [];
    for (final g in groups) {
      socket.joinGroup(g.id);
    }

    // Listen for incoming real-time socket events
    final subscription = socket.realtimeEvents.listen((event) {
      final type = event['type'] as String?;
      final groupId = event['groupId'] as String?;

      if (groupId != null && groupId.isNotEmpty) {
        ref.invalidate(groupDetailProvider(groupId));
        ref.invalidate(groupExpensesProvider(groupId));
        ref.invalidate(groupInvitationsProvider(groupId));
        ref.invalidate(groupSettlementsProvider(groupId));
        ref.invalidate(groupSimplifiedDebtsProvider(groupId));
      }

      ref.invalidate(userExpensesProvider);
      ref.invalidate(groupsNotifierProvider);
      ref.invalidate(settlementsNotifierProvider);
      ref.invalidate(pendingInvitationsProvider);
    });

    ref.onDispose(() {
      subscription.cancel();
      socket.disconnect();
    });
  } else {
    socket.disconnect();
  }
});
