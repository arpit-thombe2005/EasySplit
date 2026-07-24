import 'package:flutter_test/flutter_test.dart';
import 'package:easy_split/features/expenses/domain/models/expense.dart';
import 'package:easy_split/features/auth/domain/models/user.dart';

void main() {
  group('Offline Mode Model Tests', () {
    test('Expense supports offline sync metadata fields', () {
      final expense = Expense(
        id: 'offline_123',
        groupId: 'group_1',
        paidBy: 'user_1',
        title: 'Dinner Test',
        amount: 250.0,
        isPendingSync: true,
        syncFailed: false,
        localId: 'offline_123',
      );

      expect(expense.isPendingSync, isTrue);
      expect(expense.syncFailed, isFalse);
      expect(expense.localId, equals('offline_123'));

      final json = expense.toJson();
      final restored = Expense.fromJson(json);

      expect(restored.isPendingSync, isTrue);
      expect(restored.syncFailed, isFalse);
      expect(restored.localId, equals('offline_123'));
    });

    test('User serialization supports local caching', () {
      final user = User(
        id: 'u1',
        email: 'test@easysplit.com',
        name: 'Test User',
        currency: 'INR',
      );

      final json = user.toJson();
      final restored = User.fromJson(json);

      expect(restored.id, equals('u1'));
      expect(restored.name, equals('Test User'));
      expect(restored.currency, equals('INR'));
    });
  });
}
