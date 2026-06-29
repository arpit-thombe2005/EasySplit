import 'package:easy_split/core/constants/app_constants.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';

/// Service for computing expense splits across participants.
class SplitCalculatorService {
  SplitCalculatorService._();

  /// Compute [ParticipantInput] list for a given split type.
  ///
  /// [totalAmount] — total expense amount
  /// [userIds] — list of participant user IDs
  /// [splitType] — how to split
  /// [exactAmounts] — for [SplitType.exact]: map of userId → amount
  /// [percentages] — for [SplitType.percentage]: map of userId → percentage
  /// [shares] — for [SplitType.shares]: map of userId → share count
  static List<ParticipantInput> compute({
    required double totalAmount,
    required List<String> userIds,
    required SplitType splitType,
    Map<String, double>? exactAmounts,
    Map<String, double>? percentages,
    Map<String, int>? shares,
  }) {
    if (userIds.isEmpty) return [];

    switch (splitType) {
      case SplitType.equal:
        return _computeEqual(totalAmount, userIds);
      case SplitType.exact:
        return _computeExact(totalAmount, userIds, exactAmounts ?? {});
      case SplitType.percentage:
        return _computePercentage(totalAmount, userIds, percentages ?? {});
      case SplitType.shares:
        return _computeShares(totalAmount, userIds, shares ?? {});
    }
  }

  static List<ParticipantInput> _computeEqual(
      double total, List<String> userIds) {
    final perPerson = total / userIds.length;
    final List<ParticipantInput> result = [];

    // Handle rounding: last person absorbs the difference
    double distributed = 0;
    for (int i = 0; i < userIds.length; i++) {
      double amount;
      if (i == userIds.length - 1) {
        amount = double.parse((total - distributed).toStringAsFixed(2));
      } else {
        amount = double.parse(perPerson.toStringAsFixed(2));
        distributed += amount;
      }
      result.add(ParticipantInput(
        userId: userIds[i],
        shareAmount: amount,
        percentage: double.parse((100 / userIds.length).toStringAsFixed(2)),
      ));
    }
    return result;
  }

  static List<ParticipantInput> _computeExact(
      double total, List<String> userIds, Map<String, double> exactAmounts) {
    return userIds.map((id) {
      final amount = exactAmounts[id] ?? 0;
      return ParticipantInput(
        userId: id,
        shareAmount: amount,
        percentage: total > 0 ? double.parse((amount / total * 100).toStringAsFixed(2)) : 0,
      );
    }).toList();
  }

  static List<ParticipantInput> _computePercentage(
      double total, List<String> userIds, Map<String, double> percentages) {
    final List<ParticipantInput> result = [];
    double distributed = 0;
    for (int i = 0; i < userIds.length; i++) {
      final pct = percentages[userIds[i]] ?? 0;
      double amount;
      if (i == userIds.length - 1) {
        amount = double.parse((total - distributed).toStringAsFixed(2));
      } else {
        amount = double.parse((total * pct / 100).toStringAsFixed(2));
        distributed += amount;
      }
      result.add(ParticipantInput(
        userId: userIds[i],
        shareAmount: amount,
        percentage: pct,
      ));
    }
    return result;
  }

  static List<ParticipantInput> _computeShares(
      double total, List<String> userIds, Map<String, int> sharesMap) {
    final totalShares =
        sharesMap.values.fold<int>(0, (sum, s) => sum + s);
    if (totalShares == 0) return _computeEqual(total, userIds);

    final List<ParticipantInput> result = [];
    double distributed = 0;
    for (int i = 0; i < userIds.length; i++) {
      final shareCount = sharesMap[userIds[i]] ?? 1;
      double amount;
      if (i == userIds.length - 1) {
        amount = double.parse((total - distributed).toStringAsFixed(2));
      } else {
        amount = double.parse((total * shareCount / totalShares).toStringAsFixed(2));
        distributed += amount;
      }
      result.add(ParticipantInput(
        userId: userIds[i],
        shareAmount: amount,
        percentage: double.parse((shareCount / totalShares * 100).toStringAsFixed(2)),
        shares: shareCount,
      ));
    }
    return result;
  }

  /// Validate that exact amounts sum to total (within ₹0.01 tolerance).
  static bool validateExactAmounts(double total, Map<String, double> amounts) {
    final sum = amounts.values.fold<double>(0, (a, b) => a + b);
    return (sum - total).abs() < 0.01;
  }

  /// Validate that percentages sum to 100 (within 0.1% tolerance).
  static bool validatePercentages(Map<String, double> percentages) {
    final sum = percentages.values.fold<double>(0, (a, b) => a + b);
    return (sum - 100).abs() < 0.1;
  }
}
