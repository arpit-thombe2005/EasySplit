import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:easy_split/core/constants/app_constants.dart';

part 'settlement.freezed.dart';
part 'settlement.g.dart';

/// Domain model for a debt Settlement.
@freezed
abstract class Settlement with _$Settlement {
  const factory Settlement({
    required String id,
    required String fromUser,
    required String toUser,
    String? groupId,
    required double amount,
    @Default(SettlementStatus.pending) SettlementStatus status,
    DateTime? settledAt,
    DateTime? createdAt,
    // Enriched names
    String? fromUserName,
    String? toUserName,
    String? fromUserAvatar,
    String? toUserAvatar,
  }) = _Settlement;

  factory Settlement.fromJson(Map<String, dynamic> json) =>
      _$SettlementFromJson(json);
}
