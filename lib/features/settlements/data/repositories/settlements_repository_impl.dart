import 'package:easy_split/core/services/api_service.dart';
import 'package:easy_split/core/utils/debt_simplification.dart';
import 'package:easy_split/features/settlements/domain/models/settlement.dart';
import 'package:easy_split/features/settlements/domain/repositories/settlements_repository.dart';

/// Concrete implementation of [SettlementsRepository].
class SettlementsRepositoryImpl implements SettlementsRepository {
  final ApiService _api;

  SettlementsRepositoryImpl({required ApiService api}) : _api = api;

  @override
  Future<List<Settlement>> getGroupSettlements(String groupId) async {
    final data = await _api.get('/groups/$groupId/settlements');
    final list = data['settlements'] as List<dynamic>;
    return list
        .map((s) => Settlement.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Settlement>> getMySettlements() async {
    final data = await _api.get('/settlements/me');
    final list = data['settlements'] as List<dynamic>;
    return list
        .map((s) => Settlement.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Settlement> markSettled(String settlementId) async {
    final data = await _api.patch('/settlements/$settlementId/settle');
    return Settlement.fromJson(data['settlement'] as Map<String, dynamic>);
  }

  @override
  Future<List<DebtTransaction>> getSimplifiedDebts(String groupId) async {
    final data = await _api.get('/groups/$groupId/debts/simplified');
    final list = data['debts'] as List<dynamic>;
    return list
        .map((d) => DebtTransaction(
              fromUserId: d['from_user_id'] as String,
              toUserId: d['to_user_id'] as String,
              amount: (d['amount'] as num).toDouble(),
              fromUserName: d['from_user_name'] as String? ?? '',
              toUserName: d['to_user_name'] as String? ?? '',
            ))
        .toList();
  }

  @override
  Future<Settlement> createSettlement({
    required String toUserId,
    required String groupId,
    required double amount,
  }) async {
    final data = await _api.post('/settlements', data: {
      'to_user': toUserId,
      'group_id': groupId,
      'amount': amount,
    });
    return Settlement.fromJson(data['settlement'] as Map<String, dynamic>);
  }
}
