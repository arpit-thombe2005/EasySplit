import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';
import 'package:easy_split/features/groups/domain/models/group.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/features/groups/domain/models/invitation.dart';

/// Service responsible for offline data caching using SharedPreferences.
class LocalCacheService {
  static const _userKey = 'cached_user_profile';
  static const _groupsKey = 'cached_groups_list';
  static const _myExpensesKey = 'cached_my_expenses';
  static const _pendingExpensesKey = 'pending_expenses_queue';
  static const _mySettlementsKey = 'cached_my_settlements';
  static const _pendingInvitationsKey = 'cached_pending_invitations';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── User ──────────────────────────────────────────────────────────

  Future<void> saveUser(User user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getCachedUser() async {
    final prefs = await _prefs;
    final data = prefs.getString(_userKey);
    if (data == null) return null;
    try {
      return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserCache() async {
    final prefs = await _prefs;
    await prefs.remove(_userKey);
    await prefs.remove(_groupsKey);
    await prefs.remove(_myExpensesKey);
    await prefs.remove(_pendingExpensesKey);
    await prefs.remove(_mySettlementsKey);
    await prefs.remove(_pendingInvitationsKey);
  }

  // ── Groups ────────────────────────────────────────────────────────

  Future<void> saveGroups(List<Group> groups) async {
    final prefs = await _prefs;
    final jsonList = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_groupsKey, jsonEncode(jsonList));
  }

  Future<List<Group>> getCachedGroups() async {
    final prefs = await _prefs;
    final data = prefs.getString(_groupsKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGroupDetail(Group group) async {
    final prefs = await _prefs;
    await prefs.setString('cached_group_${group.id}', jsonEncode(group.toJson()));
  }

  Future<Group?> getCachedGroupDetail(String groupId) async {
    final prefs = await _prefs;
    final data = prefs.getString('cached_group_$groupId');
    if (data == null) return null;
    try {
      return Group.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Expenses ──────────────────────────────────────────────────────

  Future<void> saveGroupExpenses(String groupId, List<Expense> expenses) async {
    final prefs = await _prefs;
    final jsonList = expenses.map((e) => e.toJson()).toList();
    await prefs.setString('cached_expenses_$groupId', jsonEncode(jsonList));
  }

  Future<List<Expense>> getCachedGroupExpenses(String groupId) async {
    final prefs = await _prefs;
    final data = prefs.getString('cached_expenses_$groupId');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMyExpenses(List<Expense> expenses) async {
    final prefs = await _prefs;
    final jsonList = expenses.map((e) => e.toJson()).toList();
    await prefs.setString(_myExpensesKey, jsonEncode(jsonList));
  }

  Future<List<Expense>> getCachedMyExpenses() async {
    final prefs = await _prefs;
    final data = prefs.getString(_myExpensesKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Pending Offline Expenses ────────────────────────────────────────

  Future<void> savePendingExpense(Expense expense) async {
    final pending = await getPendingExpenses();
    // Remove if existing (by localId or id) and replace
    final updated = pending.where((e) => e.id != expense.id && e.localId != expense.localId).toList();
    updated.add(expense);

    final prefs = await _prefs;
    final jsonList = updated.map((e) => e.toJson()).toList();
    await prefs.setString(_pendingExpensesKey, jsonEncode(jsonList));
  }

  Future<List<Expense>> getPendingExpenses() async {
    final prefs = await _prefs;
    final data = prefs.getString(_pendingExpensesKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> removePendingExpense(String idOrLocalId) async {
    final pending = await getPendingExpenses();
    final updated = pending.where((e) => e.id != idOrLocalId && e.localId != idOrLocalId).toList();

    final prefs = await _prefs;
    final jsonList = updated.map((e) => e.toJson()).toList();
    await prefs.setString(_pendingExpensesKey, jsonEncode(jsonList));
  }

  Future<void> updatePendingExpense(Expense expense) async {
    await savePendingExpense(expense);
  }

  // ── Settlements ───────────────────────────────────────────────────

  Future<void> saveGroupSettlements(String groupId, List<Settlement> settlements) async {
    final prefs = await _prefs;
    final jsonList = settlements.map((s) => s.toJson()).toList();
    await prefs.setString('cached_settlements_$groupId', jsonEncode(jsonList));
  }

  Future<List<Settlement>> getCachedGroupSettlements(String groupId) async {
    final prefs = await _prefs;
    final data = prefs.getString('cached_settlements_$groupId');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Settlement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMySettlements(List<Settlement> settlements) async {
    final prefs = await _prefs;
    final jsonList = settlements.map((s) => s.toJson()).toList();
    await prefs.setString(_mySettlementsKey, jsonEncode(jsonList));
  }

  Future<List<Settlement>> getCachedMySettlements() async {
    final prefs = await _prefs;
    final data = prefs.getString(_mySettlementsKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => Settlement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Invitations ───────────────────────────────────────────────────

  Future<void> savePendingInvitations(List<GroupInvitation> invitations) async {
    final prefs = await _prefs;
    final jsonList = invitations.map((i) => i.toJson()).toList();
    await prefs.setString(_pendingInvitationsKey, jsonEncode(jsonList));
  }

  Future<List<GroupInvitation>> getCachedPendingInvitations() async {
    final prefs = await _prefs;
    final data = prefs.getString(_pendingInvitationsKey);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => GroupInvitation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});
