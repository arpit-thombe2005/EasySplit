import 'package:easy_split/features/settlements/domain/models/settlement.dart';

/// Abstract repository interface for settlement operations.
abstract class SettlementsRepository {
  /// Get all settlements for a group.
  Future<List<Settlement>> getGroupSettlements(String groupId);

  /// Get all settlements involving the current user (across groups).
  Future<List<Settlement>> getMySettlements();

  /// Record a new payment settlement (status = pending).
  Future<Settlement> recordPayment({
    required String toUserId,
    String? groupId,
    required double amount,
    String paymentMethod = 'UPI',
    String? note,
  });

  /// Receiver confirms a pending payment settlement (status = completed).
  Future<Settlement> confirmPayment(String settlementId);

  /// Receiver rejects a pending payment settlement (status = rejected).
  Future<Settlement> rejectPayment(String settlementId);
}
