import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/core/utils/debt_simplification.dart';

/// Abstract repository interface for settlement operations.
abstract class SettlementsRepository {
  /// Get all settlements for a group.
  Future<List<Settlement>> getGroupSettlements(String groupId);

  /// Get all settlements involving the current user (across groups).
  Future<List<Settlement>> getMySettlements();

  /// Mark a settlement as completed.
  Future<Settlement> markSettled(String settlementId);

  /// Get simplified debt transactions for a group.
  Future<List<DebtTransaction>> getSimplifiedDebts(String groupId);

  /// Create a settlement record manually.
  Future<Settlement> createSettlement({
    required String toUserId,
    required String groupId,
    required double amount,
  });
}
