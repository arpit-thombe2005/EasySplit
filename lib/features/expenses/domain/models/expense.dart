import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

/// Domain model for an Expense.
@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String groupId,
    required String paidBy,
    required String title,
    required double amount,
    @Default('Other') String category,
    String? notes,
    @Default(SplitType.equal) SplitType splitType,
    @Default([]) List<ExpenseParticipant> participants,
    UserRef? paidByUser,
    DateTime? expenseDate,
    DateTime? createdAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}

/// Domain model for an expense participant's share.
@freezed
abstract class ExpenseParticipant with _$ExpenseParticipant {
  const factory ExpenseParticipant({
    required String id,
    required String expenseId,
    required String userId,
    required double shareAmount,
    @Default(0.0) double percentage,
    @Default(1) int shares,
    UserRef? user,
  }) = _ExpenseParticipant;

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) =>
      _$ExpenseParticipantFromJson(json);
}

/// Input model for creating/editing an expense.
@freezed
abstract class ExpenseInput with _$ExpenseInput {
  const factory ExpenseInput({
    required String groupId,
    required String paidBy,
    required String title,
    required double amount,
    @Default('Other') String category,
    String? notes,
    @Default(SplitType.equal) SplitType splitType,
    required List<ParticipantInput> participants,
    DateTime? expenseDate,
  }) = _ExpenseInput;
}

/// Input for a single participant in an expense creation
@freezed
abstract class ParticipantInput with _$ParticipantInput {
  const factory ParticipantInput({
    required String userId,
    @Default(0.0) double shareAmount,
    @Default(0.0) double percentage,
    @Default(1) int shares,
  }) = _ParticipantInput;
}
