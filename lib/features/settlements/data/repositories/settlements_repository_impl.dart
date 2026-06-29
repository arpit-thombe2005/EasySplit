import 'package:easy_split/core/services/api_service.dart';
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
  Future<Settlement> recordPayment({
    required String toUserId,
    String? groupId,
    required double amount,
    String paymentMethod = 'UPI',
    String? note,
  }) async {
    final data = await _api.post('/settlements', data: {
      'to_user': toUserId,
      'group_id': groupId,
      'amount': amount,
      'payment_method': paymentMethod,
      'note': note,
    });
    return Settlement.fromJson(data['settlement'] as Map<String, dynamic>);
  }

  @override
  Future<Settlement> confirmPayment(String settlementId) async {
    final data = await _api.patch('/settlements/$settlementId/confirm');
    return Settlement.fromJson(data['settlement'] as Map<String, dynamic>);
  }

  @override
  Future<Settlement> rejectPayment(String settlementId) async {
    final data = await _api.patch('/settlements/$settlementId/reject');
    return Settlement.fromJson(data['settlement'] as Map<String, dynamic>);
  }
}
