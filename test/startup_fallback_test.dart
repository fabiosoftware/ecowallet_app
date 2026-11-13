import 'dart:async';

import 'package:ecowallet/app/data/repositories/local_expense_repository.dart';
import 'package:ecowallet/app/domain/entities/expense_category.dart';
import 'package:ecowallet/app/domain/entities/expense_entity.dart';
import 'package:ecowallet/app/domain/repositories/expense_repository.dart';
import 'package:ecowallet/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Firebase failure selects the persistent local repository', () async {
    Object? reportedError;
    final repository = await initializeWithOfflineFallback<ExpenseRepository>(
      online: () => Future.error(StateError('Firebase indisponível')),
      offline: LocalExpenseRepository.create,
      timeout: const Duration(seconds: 1),
      onError: (error) => reportedError = error,
    );

    expect(reportedError, isA<StateError>());
    expect(repository, isA<LocalExpenseRepository>());
    await repository.addExpense(
      ExpenseEntity(
        id: '1',
        amount: 12.5,
        category: ExpenseCategory.food,
        date: DateTime(2026, 1, 1),
      ),
    );
    final reopened = await LocalExpenseRepository.create();
    expect((await reopened.watchExpenses().first).single.amount, 12.5);
  });

  test('a stalled Firebase initialization falls back after the timeout',
      () async {
    Object? reportedError;
    final pending = Completer<ExpenseRepository>();
    final repository = await initializeWithOfflineFallback<ExpenseRepository>(
      online: () => pending.future,
      offline: LocalExpenseRepository.create,
      timeout: const Duration(milliseconds: 20),
      onError: (error) => reportedError = error,
    );

    expect(repository, isA<LocalExpenseRepository>());
    expect(reportedError, isA<TimeoutException>());
  });

  test('successful initialization does not open the offline repository',
      () async {
    final expected = await LocalExpenseRepository.create();
    var offlineCalled = false;
    final result = await initializeWithOfflineFallback<ExpenseRepository>(
      online: () async => expected,
      offline: () {
        offlineCalled = true;
        throw StateError('offline should not run');
      },
      timeout: const Duration(seconds: 1),
      onError: (_) => fail('unexpected failure'),
    );

    expect(result, same(expected));
    expect(offlineCalled, isFalse);
  });

  test('offline initialization errors are not reported as success', () async {
    await expectLater(
      initializeWithOfflineFallback<ExpenseRepository>(
        online: () => throw StateError('Firebase indisponível'),
        offline: () => throw StateError('armazenamento indisponível'),
        timeout: const Duration(seconds: 1),
        onError: (_) {},
      ),
      throwsStateError,
    );
  });
}
