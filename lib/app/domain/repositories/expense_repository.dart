import '../entities/expense_entity.dart';

abstract class ExpenseRepository {
  /// Emite a lista completa ordenada do mais recente para o mais antigo.
  Stream<List<ExpenseEntity>> watchExpenses();

  Future<void> addExpense(ExpenseEntity expense);
}
