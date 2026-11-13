import 'dart:async';

import 'package:ecowallet/app/data/repositories/in_memory_expense_repository.dart';
import 'package:ecowallet/src/domain/services/card_transaction_listener_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not process automated card transactions for free plan', () async {
    final planAccess = StreamController<bool>.broadcast();
    final expenses = InMemoryExpenseRepository();
    final service = CardTransactionListenerService(
      expenseRepository: expenses,
      planAccess: planAccess.stream,
    )..start();
    addTearDown(() async {
      await service.dispose();
      await planAccess.close();
    });

    planAccess.add(false);
    await Future<void>.delayed(Duration.zero);
    service.onCardTransaction(_transaction('free-transaction'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(await expenses.watchExpenses().first, isEmpty);

    planAccess.add(true);
    await Future<void>.delayed(Duration.zero);
    service.onCardTransaction(_transaction('starter-transaction'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      (await expenses.watchExpenses().first).map((expense) => expense.id),
      contains('starter-transaction'),
    );
  });
}

CardTransactionEvent _transaction(String id) => CardTransactionEvent(
      id: id,
      valor: 25,
      estabelecimento: 'Mercado local',
      timestamp: DateTime(2026, 1, 1),
    );
