import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_split/core/services/connectivity_service.dart';
import 'package:easy_split/core/services/local_cache_service.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/expenses/presentation/providers/expenses_provider.dart';

/// Service responsible for automatically syncing offline pending expenses when online.
class OfflineSyncService {
  final Ref _ref;
  bool _isSyncing = false;

  OfflineSyncService(this._ref) {
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _ref.listen<bool>(isOnlineProvider, (prev, isOnline) {
      if (isOnline == true && prev == false) {
        if (kDebugMode) print('Network restored — triggering offline expense sync...');
        syncPendingExpenses();
      }
    });
  }

  /// Synchronize all pending expenses in chronological order.
  Future<void> syncPendingExpenses() async {
    if (_isSyncing) return;
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) return;

    _isSyncing = true;
    try {
      final cache = _ref.read(localCacheServiceProvider);
      final pendingList = await cache.getPendingExpenses();

      if (pendingList.isEmpty) return;

      // Sort by creation date (chronological order)
      pendingList.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      final repo = _ref.read(expensesRepositoryProvider);

      for (final pending in pendingList) {
        try {
          final input = ExpenseInput(
            groupId: pending.groupId,
            paidBy: pending.paidBy,
            title: pending.title,
            amount: pending.amount,
            category: pending.category,
            notes: pending.notes,
            splitType: pending.splitType,
            participants: pending.participants.map((p) => ParticipantInput(
              userId: p.userId,
              shareAmount: p.shareAmount,
              percentage: p.percentage,
              shares: p.shares,
            )).toList(),
            expenseDate: pending.expenseDate,
          );

          // Attempt server creation
          final createdExpense = await repo.createExpense(input);

          // 1. Remove from pending queue
          await cache.removePendingExpense(pending.id);
          if (pending.localId != null) {
            await cache.removePendingExpense(pending.localId!);
          }

          // 2. Update cached group expenses (replace local pending with created)
          final cachedGroupExpenses = await cache.getCachedGroupExpenses(pending.groupId);
          final updatedGroupExp = cachedGroupExpenses.map((e) =>
              (e.id == pending.id || e.localId == pending.localId || e.id == pending.localId)
                  ? createdExpense
                  : e
          ).toList();
          if (!updatedGroupExp.any((e) => e.id == createdExpense.id)) {
            updatedGroupExp.insert(0, createdExpense);
          }
          await cache.saveGroupExpenses(pending.groupId, updatedGroupExp);

          // 3. Update cached my expenses
          final cachedMy = await cache.getCachedMyExpenses();
          final updatedMyExp = cachedMy.map((e) =>
              (e.id == pending.id || e.localId == pending.localId || e.id == pending.localId)
                  ? createdExpense
                  : e
          ).toList();
          if (!updatedMyExp.any((e) => e.id == createdExpense.id)) {
            updatedMyExp.insert(0, createdExpense);
          }
          await cache.saveMyExpenses(updatedMyExp);

          // Invalidate Riverpod providers so UI reflects synced state
          _ref.invalidate(groupExpensesProvider(pending.groupId));
          _ref.invalidate(userExpensesProvider);
        } catch (e) {
          if (kDebugMode) print('Failed to sync expense "${pending.title}": $e');

          // Mark expense as failed sync
          final failedExp = pending.copyWith(
            isPendingSync: true,
            syncFailed: true,
            syncError: e.toString(),
          );

          await cache.updatePendingExpense(failedExp);

          // Update cached group expenses with failed marker
          final cachedGroupExpenses = await cache.getCachedGroupExpenses(pending.groupId);
          final updatedGroupExp = cachedGroupExpenses.map((e) =>
              (e.id == pending.id || e.localId == pending.localId) ? failedExp : e
          ).toList();
          await cache.saveGroupExpenses(pending.groupId, updatedGroupExp);

          // Update cached my expenses
          final cachedMy = await cache.getCachedMyExpenses();
          final updatedMyExp = cachedMy.map((e) =>
              (e.id == pending.id || e.localId == pending.localId) ? failedExp : e
          ).toList();
          await cache.saveMyExpenses(updatedMyExp);

          _ref.invalidate(groupExpensesProvider(pending.groupId));
          _ref.invalidate(userExpensesProvider);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(ref);
});
