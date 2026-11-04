import 'dart:async';

import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';

/// Usado quando o Firebase ainda não está configurado (e nos testes).
class InMemoryExpenseRepository implements ExpenseRepository {
  final List<ExpenseEntity> _items = [];
  final StreamController<List<ExpenseEntity>> _controller =
      StreamController<List<ExpenseEntity>>.broadcast();

  List<ExpenseEntity> get _sorted =>
      List.unmodifiable([..._items]..sort((a, b) => b.date.compareTo(a.date)));

  @override
  Stream<List<ExpenseEntity>> watchExpenses() async* {
    yield _sorted;
    yield* _controller.stream;
  }

  @override
  Future<void> addExpense(ExpenseEntity expense) async {
    _items.add(expense);
    _controller.add(_sorted);
  }
}
